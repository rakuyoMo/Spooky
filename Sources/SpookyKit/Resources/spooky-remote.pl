#!/usr/bin/perl

use strict;
use warnings;

# 每条 Git 命令都经 run 启动一次包装器，这里只加载 run 用到的模块；其余模块在用到它们的地方 require。
use IO::Select;
use IO::Socket::UNIX;
use POSIX qw(EINTR setsid WNOHANG);
use Time::HiRes qw(time sleep);

# 登录时的 umask：run 启动的命令按它运行，替换写入的新文件按它取权限。
my $login_umask = umask;

# 包装器只管理本会话的操作与临时文件，凭据只在内存和 socket 中传递。
umask 0077;
$SIG{PIPE} = 'IGNORE';
my $mode = $0 =~ /-git-askpass\z/ ? 'askpass'
    : $0 =~ /-askpass\z/ ? 'ssh-askpass'
    : $0 =~ /-gpg\z/ ? 'gpg'
    : $0 =~ /-ssh-keygen\z/ ? 'ssh-keygen' : (shift(@ARGV) // '');

# 随机标识来自内核，不能由仓库内容决定操作身份。
sub identifier {
    open my $random, '<:raw', '/dev/urandom' or die "random source unavailable\n";
    read($random, my $bytes, 24) == 24 or die "random source failed\n";
    close $random;
    return unpack('H*', $bytes);
}

# 单行 JSON 有明确上限，拒绝截断报文和无限增长的输入。
sub read_message {
    my ($handle) = @_;
    require JSON::PP;
    my $data = '';

    while (length($data) <= 8 * 1024 * 1024) {
        my $count = sysread($handle, my $chunk, 4096);

        # run 等待控制报文时，子命令退出的 CHLD 信号会打断读取，重读即可
        next if !defined($count) && $! == EINTR;

        die "relay channel closed\n" unless $count;
        $data .= $chunk;
        my $end = index($data, "\n");

        if ($end >= 0) {
            $data = substr($data, 0, $end);
            last;
        }
    }

    die "relay message too large\n" if length($data) > 8 * 1024 * 1024;
    return JSON::PP::decode_json($data);
}

# 每条应答写全，远端断线不能被误认为请求已交付。
sub write_message {
    my ($handle, $message) = @_;
    require JSON::PP;
    my $data = JSON::PP::encode_json($message) . "\n";

    while (length $data) {
        my $count = syswrite($handle, $data);
        die "relay write failed\n" unless $count;
        substr($data, 0, $count, '');
    }
}

# 只信任由当前用户创建的私有会话目录，拒绝符号链接和宽权限。
sub check_session {
    my ($session) = @_;
    my @attributes = lstat($session);

    die "invalid session directory\n" unless @attributes && -d _ && !-l _
        && $attributes[4] == $< && ($attributes[2] & 0777) == 0700;
}

# 会话令牌只在发回调请求时用到，其它模式只核对会话目录。
sub session_info {
    my ($session) = @_;
    check_session($session);
    require JSON::PP;

    open my $file, '<:raw', "$session/session.json" or die "session unavailable\n";
    local $/;
    my $info = JSON::PP::decode_json(<$file>);
    close $file;
    return $info;
}

# 请求始终走当前主连接转发的 Unix socket，并等待一次性应答。
sub relay_request {
    my ($session, $request, $timeout) = @_;
    my $info = session_info($session);
    local $SIG{ALRM} = sub { die "relay request timed out\n" };
    alarm($timeout);
    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => "$session/relay.sock"
    ) or die "relay unavailable\n";
    $request->{token} = $info->{token};
    $request->{id} = identifier();
    write_message($socket, $request);
    my $response = read_message($socket);
    close $socket;
    alarm(0);
    die "relay request refused\n" unless $response->{accepted};
    return $response->{value} // '';
}

# 控制只发到操作自己的 socket，不按来自客户端的任意 PID 发信号。
sub cancel_operation {
    my ($session, $operation, $grace) = @_;
    die "invalid operation identifier\n" unless $operation =~ /\A[a-f0-9-]{36}\z/;
    open my $flag, '>', "$session/cancel-$operation" or return 0;
    close $flag;
    my $deadline = time() + $grace + 5;

    while (time() < $deadline) {
        return 1 if -f "$session/$operation/done";
        my $socket = IO::Socket::UNIX->new(
            Type => SOCK_STREAM,
            Peer => "$session/$operation/control.sock"
        );

        if ($socket) {
            eval {
                local $SIG{ALRM} = sub { die "cancel confirmation timed out\n" };
                alarm(int($grace) + 4);
                write_message($socket, { cancel => \1 });
                my $reply = read_message($socket);
                alarm(0);
                close $socket;
                return $reply->{confirmed} ? 1 : 0;
            } and return 1;
        }

        sleep(0.05);
    }

    return 0;
}

# 主连接消失后终止本会话的进程组，再删除所有运行时文件。
sub clean_session {
    my ($session) = @_;
    return unless -d $session;
    opendir my $directory, $session or return;
    my @operations = grep { /\A[a-f0-9-]{36}\z/ } readdir($directory);
    closedir $directory;
    my $confirmed = 1;

    for my $operation (@operations) {
        $confirmed = cancel_operation($session, $operation, 2) && $confirmed;
    }

    if ($confirmed) {
        require File::Path;
        File::Path::remove_tree($session);
    }

    return $confirmed;
}

# 子进程独占一个进程组，控制连接只终止这组中的进程。
sub run_operation {
    my ($session, $operation, $grace, @command) = @_;
    check_session($session);
    die "invalid operation identifier\n" unless $operation =~ /\A[a-f0-9-]{36}\z/;
    die "invalid cancellation grace\n" unless $grace =~ /\A\d+(?:\.\d+)?\z/ && $grace <= 30;
    mkdir("$session/$operation", 0700) or die "operation already exists\n";
    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Local => "$session/$operation/control.sock",
        Listen => 4
    ) or die "operation control unavailable\n";

    # 子命令一退出，CHLD 处理就往自唤醒管道写一个字节，等在 select 上的循环随即醒来回收它；
    # 处理要在 fork 之前装上，退出得早的子命令同样不会漏掉。
    pipe(my $wake_read, my $wake_write) or die "process monitor unavailable\n";
    IO::Handle::blocking($wake_write, 0);
    local $SIG{CHLD} = sub { syswrite($wake_write, '1') };

    my $pid = start_process($session, $operation, [$socket, $wake_read, $wake_write], @command);
    $SIG{HUP} = 'IGNORE';

    my ($status, $cancelled, $reply_socket) = supervise_process(
        $pid,
        $grace,
        "$session/cancel-$operation",
        $socket,
        $wake_read
    );

    open my $done, '>', "$session/$operation/done" or die "cannot confirm operation\n";
    close $done;
    eval { write_message($reply_socket, { confirmed => \1 }) } if $reply_socket;
    close $socket;
    unlink "$session/$operation/control.sock";
    my $code = $status >> 8;
    my $signal = $status & 127;

    # 随机操作标识使 Git 的 255 与 SSH 的 255 可被可靠地区分。
    print STDERR "\x1eSPOOKY:$operation:$code:$signal:" . ($cancelled ? 1 : 0) . "\x1f";
    return $signal ? 128 + $signal : $code;
}

# 在新的会话与进程组里启动子命令，等它脱离包装器的进程组后返回 PID；
# 子命令不继承包装器持有的描述符与 CHLD 处理。
sub start_process {
    my ($session, $operation, $inherited, @command) = @_;
    pipe(my $ready_read, my $ready_write) or die "process handshake unavailable\n";
    my $pid = fork();
    die "cannot start operation\n" unless defined $pid;

    if ($pid == 0) {
        $SIG{CHLD} = 'DEFAULT';
        close $ready_read;
        close $_ for @$inherited;
        setsid() >= 0 or POSIX::_exit(126);
        syswrite($ready_write, '1');
        close $ready_write;
        $SIG{PIPE} = 'DEFAULT';
        $SIG{HUP} = 'DEFAULT';

        # 清洗优先级高于 -c 的变量，使所有交互都经过本会话中继。
        delete @ENV{qw(GIT_EDITOR GIT_SEQUENCE_EDITOR GIT_ASKPASS SSH_ASKPASS
            SSH_ASKPASS_REQUIRE GIT_SSH GIT_SSH_COMMAND GIT_SSH_VARIANT
            GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE
            GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
            GIT_NAMESPACE GIT_PREFIX GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT SPOOKY_SIGNING)};
        $ENV{LANG} = $ENV{LC_ALL} = 'en_US.UTF-8';
        $ENV{GIT_TERMINAL_PROMPT} = '0';
        $ENV{SPOOKY_SESSION} = $session;
        $ENV{SPOOKY_OPERATION} = $operation;
        $ENV{GIT_SSH_VARIANT} = 'ssh';

        # 命令按登录时的 umask 运行，Git 新建的文件与直接登录执行时权限相同
        umask $login_umask;
        exec { $command[0] } @command or POSIX::_exit(127);
    }

    close $ready_write;
    read($ready_read, my $ready, 1);
    close $ready_read;
    return $pid;
}

# 等子命令连同它的进程组全部退出，期间响应取消标记与控制连接；
# 返回退出状态、是否取消，以及等待确认的控制连接。
sub supervise_process {
    my ($pid, $grace, $flag, $socket, $wake) = @_;
    my $selector = IO::Select->new($socket, $wake);
    my ($status, $cancelled, $deadline, $reply_socket);

    while (1) {
        if (!$cancelled && -f $flag) {
            $cancelled = 1;
            kill 'TERM', -$pid;
            $deadline = time() + $grace;
        }

        if (!defined($status) && waitpid($pid, WNOHANG) == $pid) {
            $status = $?;

            # 子命令退出后仍留在组内的后代同样属于本操作，必须回收。
            if (kill(0, -$pid)) {
                kill 'TERM', -$pid;
                $deadline //= time() + $grace;
            }
        }

        last if defined($status) && !kill(0, -$pid);

        if (defined($deadline) && time() >= $deadline) {
            kill 'KILL', -$pid;
        }

        # 50 ms 的步长兜底：CHLD 恰好落在上面的检查与 select 之间时，最多再等一圈
        for my $handle ($selector->can_read(0.05)) {
            if ($handle == $wake) {
                sysread($wake, my $bytes, 64);
                next;
            }

            my $client = $handle->accept();
            next unless $client;

            # 控制 socket 位于 0700 目录内，控制报文仍设短超时。
            my $request = eval {
                local $SIG{ALRM} = sub { die "control timed out\n" };
                alarm(2);
                my $request = read_message($client);
                alarm(0);
                $request;
            };

            if ($request && $request->{cancel}) {
                $cancelled = 1;
                kill 'TERM', -$pid;
                $deadline //= time() + $grace;
                $reply_socket = $client;
            } else {
                close $client;
            }
        }
    }

    return ($status, $cancelled, $reply_socket);
}

# 签名程序沿用仓库生效的配置；读取时去掉本会话追加的 -c 覆盖，否则查到的是包装器自己。
sub configured_program {
    my ($pattern, $fallback) = @_;
    local %ENV = %ENV;
    delete @ENV{qw(GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT)};
    open(my $config, '-|', 'git', 'config', '--type=path', '-z', '--get-regexp', $pattern) or return $fallback;
    local $/;
    my $output = <$config> // '';
    close $config;

    # 每条记录是 “键、换行、值”，同一程序的两个别名以最后读到的为准。
    my @values = map { (split /\n/, $_, 2)[1] } grep { length } split /\0/, $output;
    my $value = $values[-1];
    return defined($value) && length($value) ? $value : $fallback;
}

# 找不到签名程序时与 Git 自己启动失败的报错一致，原始错误随签名失败一起保留。
sub exec_program {
    my ($program, @arguments) = @_;
    {
        no warnings 'exec';
        exec { $program } $program, @arguments;
    }
    print STDERR "fatal: cannot exec '$program': $!\n";
    POSIX::_exit(127);
}

# gpg 以 loopback 方式在状态输出里索取口令；只有真正索取时才经中继询问，agent 已缓存或密钥无口令时不打扰用户。
sub sign_with_relay {
    my ($program, @arguments) = @_;
    require Encode;
    require Fcntl;
    my $session = $ENV{SPOOKY_SESSION} // die "callback session missing\n";
    my $operation = $ENV{SPOOKY_OPERATION} // die "callback operation missing\n";
    pipe(my $status_read, my $status_write) or die "signing channel unavailable\n";
    pipe(my $command_read, my $command_write) or die "signing channel unavailable\n";
    my $pid = fork();
    die "cannot start signing program\n" unless defined $pid;

    if ($pid == 0) {
        close $status_read;
        close $command_write;
        open(STDERR, '>&', $status_write) or POSIX::_exit(126);

        # 命令管道要跨过 exec 留给 gpg，Perl 默认给新描述符设了 close-on-exec。
        fcntl($command_read, Fcntl::F_SETFD(), 0) or POSIX::_exit(126);
        exec_program($program, '--pinentry-mode', 'loopback', '--command-fd', fileno($command_read), @arguments);
    }

    close $status_write;
    close $command_read;
    my ($pending, $hint, $open) = ('', '', 1);

    # Git 从标准错误读取状态行，这里原样转发；口令只写进 gpg 的命令管道。
    while (sysread($status_read, my $chunk, 4096)) {
        syswrite(STDERR, $chunk);
        $pending .= $chunk;

        while ((my $end = index($pending, "\n")) >= 0) {
            my $line = substr($pending, 0, $end + 1, '');
            next unless $open;

            if ($line =~ /\A\[GNUPG:\] USERID_HINT (.*)\n\z/) {
                $hint = $1;
            } elsif ($line =~ /\A\[GNUPG:\] GET_HIDDEN passphrase\.enter/) {
                my $request = {
                    kind => 'signing',
                    operation => $operation,
                    prompt => Encode::decode('UTF-8', $hint)
                };
                my $value = eval { relay_request($session, $request, 120) };

                # 用户取消或中继不可用时关闭命令管道，gpg 随即以取消结束。
                if (defined $value) {
                    syswrite($command_write, Encode::encode('UTF-8', $value) . "\n");
                } else {
                    close $command_write;
                    $open = 0;
                }
            } elsif ($line =~ /\A\[GNUPG:\] GET_(?:BOOL|LINE) /) {
                # 签名不应再有其它提问，回答空行可能让 gpg 反复追问，直接结束输入。
                close $command_write;
                $open = 0;
            }
        }
    }

    waitpid($pid, 0);
    return $? & 127 ? 128 + ($? & 127) : $? >> 8;
}

if ($mode eq 'create-session') {
    require File::Temp;
    require JSON::PP;
    my $request = read_message(\*STDIN);
    die "invalid session token\n" unless ($request->{token} // '') =~ /\A[a-f0-9]{64}\z/;
    my $session = File::Temp::tempdir('spooky-XXXXXXXX', DIR => '/tmp', CLEANUP => 0);
    chmod 0700, $session;
    open my $file, '>:raw', "$session/session.json" or die "cannot initialize session\n";
    print {$file} JSON::PP::encode_json({ token => $request->{token} });
    close $file;
    print "$session\n";
} elsif ($mode eq 'watch') {
    my $session = shift @ARGV;
    check_session($session);
    my $pid = fork();
    die "cannot watch session\n" unless defined $pid;
    exit 0 if $pid;
    setsid();
    open STDIN, '<', '/dev/null';
    open STDOUT, '>', '/dev/null';
    open STDERR, '>', '/dev/null';
    $SIG{HUP} = 'IGNORE';

    while (-d $session) {
        my $alive = eval { relay_request($session, { kind => 'heartbeat', operation => '' }, 3); 1 };
        last unless $alive;
        sleep(0.5);
    }

    clean_session($session);
} elsif ($mode eq 'close') {
    my $session = shift @ARGV;
    check_session($session);
    exit(clean_session($session) ? 0 : 1);
} elsif ($mode eq 'cancel') {
    my ($session, $operation, $grace) = @ARGV;
    check_session($session);
    exit(cancel_operation($session, $operation, $grace) ? 0 : 1);
} elsif ($mode eq 'run') {
    exit run_operation(@ARGV);
} elsif ($mode eq 'askpass' || $mode eq 'ssh-askpass' || $mode eq 'editor') {
    require Encode;
    my $session = $ENV{SPOOKY_SESSION} // die "callback session missing\n";
    my $operation = $ENV{SPOOKY_OPERATION} // die "callback operation missing\n";
    my $argument = shift(@ARGV) // '';
    my $request = {
        kind => $mode eq 'ssh-askpass' && $ENV{SPOOKY_SIGNING} ? 'signing' : $mode,
        operation => $operation,
        prompt => Encode::decode('UTF-8', $argument)
    };

    if ($mode eq 'editor') {
        open my $file, '<:raw', $argument or die "editor input unavailable\n";
        read($file, my $content, 4 * 1024 * 1024 + 1);
        close $file;
        die "editor input too large\n" if length($content) > 4 * 1024 * 1024;
        $request->{content} = Encode::decode('UTF-8', $content);
    }

    my $value = relay_request($session, $request, 120);

    if ($mode eq 'editor') {
        open my $file, '>:raw', $argument or die "editor output unavailable\n";
        print {$file} Encode::encode('UTF-8', $value);
        close $file;
    } else {
        print Encode::encode('UTF-8', $value), "\n";
    }
} elsif ($mode eq 'credential') {
    # Git 的凭据助手协议：get 与 erase 只把地址交给 A，令牌只经中继回到标准输出；store 等动作不交给 A，凭据不另存。
    my $action = shift(@ARGV) // '';
    exit 0 unless $action eq 'get' || $action eq 'erase';

    require Encode;
    my $session = $ENV{SPOOKY_SESSION} // die "callback session missing\n";
    my $operation = $ENV{SPOOKY_OPERATION} // die "callback operation missing\n";
    my %fields;

    # 只取协议、主机与路径；erase 带来的密码与新版 Git 的 capability、wwwauth 等行都丢掉。
    while (my $line = <STDIN>) {
        $line =~ s/\r?\n\z//;
        last if $line eq '';

        my ($key, $value) = split(/=/, $line, 2);
        $fields{$key} = $value if defined $value && $key =~ /\A(?:protocol|host|path)\z/;
    }

    exit 0 unless defined $fields{protocol} && defined $fields{host};

    my $address = "$fields{protocol}://$fields{host}/" . ($fields{path} // '');
    my $request = {
        kind => 'credential',
        operation => $operation,
        prompt => $action,
        content => Encode::decode('UTF-8', $address)
    };

    # A 不回答、拒绝或超时时什么都不输出，Git 接着问 askpass。
    my $value = eval { relay_request($session, $request, 120) } // '';
    print Encode::encode('UTF-8', $value) if $action eq 'get';
} elsif ($mode eq 'ssh') {
    $ENV{SSH_ASKPASS} = "$0-askpass";
    $ENV{SSH_ASKPASS_REQUIRE} = 'force';
    $ENV{DISPLAY} = 'spooky:0';
    exec '/usr/bin/ssh', '-o', 'ForwardAgent=no', '-o', 'StrictHostKeyChecking=yes', @ARGV;
    die "cannot launch remote ssh\n";
} elsif ($mode eq 'gpg') {
    my $program = configured_program('^gpg\.(openpgp\.)?program$', 'gpg');

    # 校验签名时不访问网络：关闭按需从密钥服务器取钥与自动检查信任库。
    exec_program($program, '--no-auto-key-retrieve', '--no-auto-check-trustdb', @ARGV)
        if grep { $_ eq '--verify' } @ARGV;

    # Git 签名固定使用 -bsau；其它调用不会索取口令，原样交给 gpg。
    exec_program($program, @ARGV) unless grep { $_ eq '-bsau' } @ARGV;
    exit sign_with_relay($program, @ARGV);
} elsif ($mode eq 'ssh-keygen') {
    # ssh-keygen 解锁私钥时经 SSH_ASKPASS 回到中继，不会等待不存在的终端；agent 里的密钥不需要口令。
    my $program = configured_program('^gpg\.ssh\.program$', 'ssh-keygen');
    (my $base = $0) =~ s/-ssh-keygen\z//;
    $ENV{SSH_ASKPASS} = "$base-askpass";
    $ENV{SSH_ASKPASS_REQUIRE} = 'force';
    $ENV{DISPLAY} = 'spooky:0';
    $ENV{SPOOKY_SIGNING} = '1';
    exec_program($program, @ARGV);
} elsif ($mode eq 'inspect') {
    # 路径由 git rev-parse --git-path 提供，只检查存在性，不读取元数据内容。
    for my $path (@ARGV) {
        print((-e $path ? '1' : '0'), "\n");
    }
} elsif ($mode eq 'replace') {
    # 标准输入的内容先写进目标所在目录里独占的临时文件，读满声明的字节数后再改名替换；
    # 出错、输入提前结束或被结束时删掉临时文件，原文件不变。
    my ($target, $size) = @ARGV;
    die "invalid replacement\n" unless defined($size) && length($target) && $size =~ /\A\d+\z/;
    require File::Basename;
    require Fcntl;

    # 目标是符号链接时替换它最终指向的文件，相对链接按链接所在的目录解析
    for (1 .. 40) {
        last unless -l $target;

        my $link = readlink($target) // die "cannot read symbolic link: $!\n";
        $target = $link =~ m{\A/} ? $link : File::Basename::dirname($target) . "/$link";
    }

    die "too many levels of symbolic links\n" if -l $target;

    # 已有的文件要可写，新内容沿用它的权限位；新文件按登录时的 umask
    my $permissions = 0666 & ~$login_umask;

    if (-e $target) {
        die "not a regular file\n" unless -f _;
        die "permission denied\n" unless -w _;
        $permissions = (stat _)[2] & 07777;
    }

    my $temporary = File::Basename::dirname($target) . '/.spooky-' . identifier();
    my $fail = sub { unlink $temporary; die "$_[0]\n" };

    # 取消时包装器先发 TERM，被结束前同样删掉临时文件
    $SIG{$_} = sub { unlink $temporary; POSIX::_exit(1) } for qw(HUP INT TERM);

    sysopen(
        my $file,
        $temporary,
        Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
        0600
    ) or die "cannot create temporary file: $!\n";
    binmode $file;
    binmode STDIN;
    chmod($permissions, $temporary) or $fail->("cannot set permissions: $!");

    my $remaining = $size;

    while ($remaining > 0) {
        my $read = sysread(STDIN, my $buffer, $remaining < 65536 ? $remaining : 65536);
        $fail->("cannot read content: $!") unless defined $read;
        $fail->("incomplete content") unless $read;

        print {$file} $buffer or $fail->("cannot write content: $!");
        $remaining -= $read;
    }

    close($file) or $fail->("cannot write content: $!");
    rename($temporary, $target) or $fail->("cannot replace file: $!");
} else {
    die "unknown wrapper operation\n";
}
