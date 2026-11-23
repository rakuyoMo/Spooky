#!/usr/bin/perl

use strict;
use warnings;

# 每条 Git 命令都经 run 启动一次包装器，这里只加载 run 用到的模块；其余模块在用到它们的地方 require。
use IO::Select;
use IO::Socket::UNIX;
use POSIX qw(EAGAIN EINTR ENOENT setsid WNOHANG);
use Time::HiRes qw(time sleep);

# 登录时的 umask：run 启动的命令按它运行，替换写入的新文件按它取权限。
my $login_umask = umask;

# 包装器自己的路径；常驻通道里的请求会改写进程标题，回调入口的路径从这里取。
my $wrapper = $0;

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
    my $response;

    my $answered = eval {
        my $socket = IO::Socket::UNIX->new(
            Type => SOCK_STREAM,
            Peer => "$session/relay.sock"
        ) or die "relay unavailable\n";
        $request->{token} = $info->{token};
        $request->{id} = identifier();
        write_message($socket, $request);
        $response = read_message($socket);
        close $socket;
        1;
    };
    my $error = $@;

    # 连不上、读写失败时同样先取消定时器：留下的定时器会在之后的清理中途按默认处理结束整个进程
    alarm(0);
    die $error unless $answered;
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
            my $confirmed = eval {
                local $SIG{ALRM} = sub { die "cancel confirmation timed out\n" };
                alarm(int($grace) + 4);
                write_message($socket, { cancel => \1 });
                my $reply = read_message($socket);
                $reply->{confirmed} ? 1 : 0;
            };

            # 读写失败时同样先取消定时器：留下的定时器会在之后的重试或清理中途按默认处理结束整个进程
            alarm(0);
            close $socket;
            return 1 if $confirmed;
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
        # 已结束的操作，以及目录已被看守过期删掉的操作不用取消：跳过它们，不留取消标记，也不空等确认
        next if -f "$session/$operation/done" || !-d "$session/$operation";

        $confirmed = cancel_operation($session, $operation, 2) && $confirmed;
    }

    if ($confirmed) {
        require File::Path;

        # 删除期间到达的取消会在已经列过的目录里留下取消标记，目录因此删不掉；还在就再删一遍，最多三遍
        for (1 .. 3) {
            File::Path::remove_tree($session);
            last unless -d $session;
        }
    }

    return $confirmed;
}

# 删掉结束超过保留期的操作目录与过期的取消标记，会话开得再久，其中的文件也不会越积越多；
# 保留期内对已结束操作的取消照样直接得到确认，执行中的操作与它的取消标记不动。
sub prune_operations {
    my ($session, $retention) = @_;
    my $expired = time() - $retention;
    opendir my $directory, $session or return;
    my @names = readdir($directory);
    closedir $directory;

    for my $operation (grep { /\A[a-f0-9-]{36}\z/ } @names) {
        my $finished = (stat("$session/$operation/done"))[9];
        next unless defined($finished) && $finished < $expired;

        unlink(
            "$session/cancel-$operation",
            "$session/$operation/control.sock",
            "$session/$operation/done"
        );
        rmdir("$session/$operation");
    }

    # 没有操作目录的取消标记属于没开始执行或目录已删掉的操作
    for my $marker (grep { /\Acancel-[a-f0-9-]{36}\z/ } @names) {
        my $created = (stat("$session/$marker"))[9];

        next if !defined($created)
            || $created >= $expired
            || -d "$session/" . substr($marker, length('cancel-'));

        unlink("$session/$marker");
    }
}

# 部署新版本时按访问时间删掉长期没人用的旧版本：这里把包装器的访问时间更新为现在，修改时间保持安装时的值。
# 挂载选项可能让读取不更新访问时间，所以明确更新；经常驻通道执行的命令不会重新读取包装器文件，会话存续期间由看守定期更新。
sub record_use {
    my $modified = (stat $wrapper)[9];
    utime(time, $modified, $wrapper) if defined $modified;
}

# 看守经中继的心跳确认 A 仍连着，心跳失败时返回；
# 会话刚建好时 A 还没把中继转发进来：转发的 socket 出现之前不发心跳，等满容忍期仍没有出现按心跳失败处理。
# 第一轮先清理一遍过期的操作并记下包装器的使用，之后每过保留期的五分之一做一遍。
# 没有回应算网络停顿，SSH 连接这时可能还撑得住，连续超过容忍期都没有成功的心跳才返回；
# 连不上转发的 socket、通道被关闭或请求被拒绝说明主连接或中继已经没了，立即返回。
sub watch_session {
    my ($session, $tolerance, $retention) = @_;
    my $started = time();

    until (-S "$session/relay.sock") {
        return if !-d $session || time() - $started > $tolerance;

        sleep(0.5);
    }

    my $answered = time();
    my $pruned = 0;

    while (-d $session) {
        my $alive = eval {
            relay_request($session, { kind => 'heartbeat', operation => '' }, 3);
            1;
        };

        if ($alive) {
            $answered = time();
        } elsif ($@ ne "relay request timed out\n" || time() - $answered > $tolerance) {
            return;
        }

        if (time() - $pruned >= $retention / 5) {
            prune_operations($session, $retention);
            record_use();
            $pruned = time();
        }

        sleep(0.5);
    }
}

# 分出会话的看守进程，看守结束后清理会话；分不出来时删掉刚建的会话目录再报错。
# 看守脱离调用方的进程组，不留调用方的标准输入输出与其它描述符：调用方读到输出结束就能继续，不被看守拖住。
sub start_watcher {
    my ($session, $tolerance, $retention) = @_;
    my $pid = fork();

    if (!defined $pid) {
        unlink "$session/session.json";
        rmdir $session;
        die "cannot watch session\n";
    }

    return if $pid;

    setsid();
    open STDIN, '<', '/dev/null';
    open STDOUT, '>', '/dev/null';
    open STDERR, '>', '/dev/null';

    # 调用方可能把别的管道留在 3 号及以后的描述符上，逐个关掉
    my $limit = POSIX::sysconf(POSIX::_SC_OPEN_MAX()) // 256;
    POSIX::close($_) for 3 .. ($limit < 4096 ? $limit : 4096) - 1;

    $SIG{HUP} = 'IGNORE';

    # 进程标题写成 “包装器 watch 会话目录”，按命令行能找到某个会话的看守
    $0 = "$wrapper watch $session";

    watch_session($session, $tolerance, $retention);
    clean_session($session);
    exit 0;
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

            # 读取失败时定时器还在走，不取消就会在 eval 之外按默认处理结束 run
            alarm(0);

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

# 常驻通道的帧，两个方向相同：长度（其后的字节数）、类型、请求标识、负载，整数都是大端。
# A 发来的类型：1 执行，负载是参数个数、逐个参数的长度与内容，其余字节是标准输入；2 放弃，不再要这个请求的输出。
# 发给 A 的类型：0 就绪，标识是协议版本；1、2 是标准输出、标准错误的一块；3 退出，负载是 1 字节退出码。
use constant {
    SERVE_VERSION => 1,
    SERVE_REQUEST_LIMIT => 8 * 1024 * 1024,
    SERVE_CHUNK => 64 * 1024,
};

# 命令退出之后，每个输出管道最多再转发的字节数。
# 命令退出时管道里它写下的内容不超过管道容量：macOS 上最大 64 KiB，Linux 上非特权进程默认最多调到 1 MiB，转发这么多足以送完；
# 脱离进程组的后代之后不停写进来的内容随管道关闭丢弃，收尾不会一直转发下去。
use constant SERVE_DRAIN_LIMIT => 1024 * 1024;

# 一个会话的命令都经这一条 SSH 会话执行：每个请求在自己的子进程里照单独启动包装器的方式执行，输出与退出码逐帧发回。
# 标准输入结束、标准输出写不出去，或会话目录已经不在时退出；执行中的请求不结束，照常执行完。
sub serve {
    my ($session) = @_;
    check_session($session);

    # 子进程一退出，CHLD 处理就往自唤醒管道写一个字节，等在 select 上的循环随即醒来回收它
    pipe(my $wake_read, my $wake_write) or die "process monitor unavailable\n";
    IO::Handle::blocking($_, 0) for $wake_read, $wake_write;
    $SIG{CHLD} = sub { local $!; syswrite($wake_write, '1') };

    my $state = {
        wake => [$wake_read, $wake_write],
        requests => {},
        processes => {},
        pending => ''
    };
    my $checked = time();
    write_frame(0, SERVE_VERSION, '');

    while (1) {
        my $selector = IO::Select->new(\*STDIN, $wake_read, serve_outputs($state));

        # 有请求在执行时用 50 ms 的步长兜底：CHLD 恰好落在回收与 select 之间时，信号处理要等 select 返回才执行，
        # 结束帧最多晚一个步长
        my $timeout = %{$state->{requests}} ? 0.05 : 1;
        my %readable = map { fileno($_) => 1 } $selector->can_read($timeout);

        # 唤醒的字节只用来打断 select，读掉即可
        if ($readable{fileno($wake_read)}) {
            sysread($wake_read, my $bytes, 4096);
        }

        reap_requests($state);
        relay_outputs($state, \%readable);
        finish_requests($state);
        return if $readable{fileno(STDIN)} && !read_requests($state);

        next if time() - $checked < 1;
        $checked = time();

        # close 删掉会话目录之后，要等它的退出帧发出去再退出
        return if !-d $session && !%{$state->{requests}};
    }
}

# 回收退出的子进程，记下请求的退出状态；标准输入的写入进程与放弃了的请求不再记着。
sub reap_requests {
    my ($state) = @_;

    while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
        my $id = delete $state->{processes}{$pid};
        $state->{requests}{$id}{status} = $? if defined $id;
    }
}

# 每个可读的输出管道每轮只转发一块，输出多的请求不会挡住别的请求。
sub relay_outputs {
    my ($state, $readable) = @_;

    for my $id (keys %{$state->{requests}}) {
        for my $stream ('output', 'error') {
            my $handle = $state->{requests}{$id}{$stream};
            relay_chunk($state, $id, $stream) if defined($handle) && $readable->{fileno($handle)};
        }
    }
}

# 子进程已回收的请求：不等管道读到末尾，转发完管道里已有的输出就发出退出帧。
# 脱离进程组的后代仍可能拿着管道，读到末尾要等它们全部退出；每个管道最多再转发 SERVE_DRAIN_LIMIT 字节。
sub finish_requests {
    my ($state) = @_;

    for my $id (grep { defined $state->{requests}{$_}{status} } keys %{$state->{requests}}) {
        for my $stream ('output', 'error') {
            my $left = SERVE_DRAIN_LIMIT;

            while ($left > 0 && defined($state->{requests}{$id}{$stream})) {
                my $count = relay_chunk($state, $id, $stream) or last;
                $left -= $count;
            }
        }

        my $request = delete $state->{requests}{$id};
        my $status = $request->{status};
        close $_ for grep { defined } @{$request}{qw(output error)};
        write_frame(3, $id, pack('C', $status & 127 ? 128 + ($status & 127) : $status >> 8));
    }
}

# 从请求的一个输出管道读一块转发给 A，读到末尾时关掉管道；返回转发的字节数。
sub relay_chunk {
    my ($state, $id, $stream) = @_;
    my $request = $state->{requests}{$id};
    my $count;

    do {
        $count = sysread($request->{$stream}, my $chunk, SERVE_CHUNK);
        write_frame($stream eq 'output' ? 1 : 2, $id, $chunk) if $count;
    } while (!defined($count) && $! == EINTR);

    return $count if $count;
    return 0 if !defined($count) && $! == EAGAIN;

    close $request->{$stream};
    $request->{$stream} = undef;
    return 0;
}

# 读一块标准输入，处理其中完整的请求帧；标准输入结束时返回假。
sub read_requests {
    my ($state) = @_;
    my $count = sysread(STDIN, $state->{pending}, SERVE_CHUNK, length($state->{pending}));
    return 1 if !defined($count) && $! == EINTR;
    return 0 unless $count;

    while (length($state->{pending}) >= 4) {
        my $length = unpack('N', $state->{pending});
        die "invalid request frame\n" if $length < 5 || $length > SERVE_REQUEST_LIMIT;
        last if length($state->{pending}) < 4 + $length;

        my ($type, $id) = unpack('x4 C N', $state->{pending});
        my $payload = substr($state->{pending}, 9, $length - 5);
        substr($state->{pending}, 0, 4 + $length, '');

        if ($type == 1) {
            start_request($state, $id, request_arguments($payload));
        } elsif ($type == 2) {
            abort_request($state, $id);
        } else {
            die "invalid request frame\n";
        }
    }

    return 1;
}

# 解开执行帧的负载：参数个数，逐个参数的长度与内容，其余字节是标准输入。
sub request_arguments {
    my ($payload) = @_;
    die "invalid request frame\n" if length($payload) < 4;
    my $count = unpack('N', $payload);
    my $offset = 4;
    my @arguments;

    for (1 .. $count) {
        die "invalid request frame\n" if $offset + 4 > length($payload);
        my $length = unpack("x$offset N", $payload);
        $offset += 4;
        die "invalid request frame\n" if $offset + $length > length($payload);
        push @arguments, substr($payload, $offset, $length);
        $offset += $length;
    }

    return (\@arguments, substr($payload, $offset));
}

# 在子进程里执行一个请求；有标准输入时另起一个进程写入，命令不读输入也不会卡住通道。
sub start_request {
    my ($state, $id, $arguments, $input) = @_;
    die "duplicate request\n" if $state->{requests}{$id};
    pipe(my $output_read, my $output_write) or die "cannot start request\n";
    pipe(my $error_read, my $error_write) or die "cannot start request\n";
    my ($input_read, $input_write);

    if (length $input) {
        pipe($input_read, $input_write) or die "cannot start request\n";
    }

    my $pid = fork();
    die "cannot start request\n" unless defined $pid;

    if ($pid == 0) {
        run_request(
            $state,
            $arguments,
            [$output_read, $error_read, $input_write],
            [$input_read, $output_write, $error_write]
        );
    }

    close $_ for $output_write, $error_write;
    IO::Handle::blocking($_, 0) for $output_read, $error_read;
    $state->{requests}{$id} = { pid => $pid, output => $output_read, error => $error_read };
    $state->{processes}{$pid} = $id;
    return unless defined $input_read;

    close $input_read;
    my $writer = fork();
    die "cannot start request\n" unless defined $writer;
    write_input($state, $input_write, $input) if $writer == 0;
    close $input_write;
}

# A 不再要这个请求的输出：关掉它的输出管道，之后不再为它发帧；子进程照常执行，退出后回收。
sub abort_request {
    my ($state, $id) = @_;
    my $request = delete $state->{requests}{$id} or return;
    delete $state->{processes}{$request->{pid}};
    close $_ for grep { defined } @{$request}{qw(output error)};
}

# 请求的子进程：只留这个请求自己的管道作标准输入、输出与错误，再按单独启动包装器的方式执行模式。
sub run_request {
    my ($state, $arguments, $unused, $streams) = @_;
    my ($input, $output, $error) = @$streams;
    $SIG{CHLD} = 'DEFAULT';
    close $_ for @{$state->{wake}}, serve_outputs($state), grep { defined } @$unused;

    if (defined $input) {
        open(STDIN, '<&', $input) or POSIX::_exit(126);
        close $input;
    } else {
        open(STDIN, '<', '/dev/null') or POSIX::_exit(126);
    }

    open(STDOUT, '>&', $output) or POSIX::_exit(126);
    open(STDERR, '>&', $error) or POSIX::_exit(126);
    close $_ for $output, $error;

    # 进程标题照单独启动时的命令行写，按命令行查找 run 等进程的办法照样适用
    $0 = join(' ', $wrapper, @$arguments);
    @ARGV = @$arguments;
    my $mode = shift(@ARGV) // '';

    # die 按 $! 与 $? 取退出码，先清掉通道循环里留下的值
    $! = 0;
    $? = 0;
    dispatch($mode);
    exit 0;
}

# 标准输入的写入进程：只留管道的写入端，写完或命令关掉了输入就退出。
sub write_input {
    my ($state, $handle, $input) = @_;
    $SIG{CHLD} = 'DEFAULT';
    close $_ for @{$state->{wake}}, serve_outputs($state);
    open(STDIN, '<', '/dev/null') or POSIX::_exit(1);
    open(STDOUT, '>', '/dev/null') or POSIX::_exit(1);
    open(STDERR, '>', '/dev/null') or POSIX::_exit(1);

    while (length $input) {
        my $count = syswrite($handle, $input);
        next if !defined($count) && $! == EINTR;
        last unless $count;
        substr($input, 0, $count, '');
    }

    POSIX::_exit(0);
}

# 执行中请求的输出管道。
sub serve_outputs {
    my ($state) = @_;
    return grep { defined } map { @{$_}{qw(output error)} } values %{$state->{requests}};
}

# 写出一整帧；标准输出写不出去说明 A 已经断开，通道随即退出。
sub write_frame {
    my ($type, $id, $payload) = @_;
    my $data = pack('NCN', 5 + length($payload), $type, $id) . $payload;

    while (length $data) {
        my $count = syswrite(STDOUT, $data);
        next if !defined($count) && $! == EINTR;
        exit 1 unless $count;
        substr($data, 0, $count, '');
    }
}

# 按模式执行一次包装器；单独启动与常驻通道里的请求都从这里进入，模式的参数在 @ARGV 里。
sub dispatch {
    my ($mode) = @_;

    if ($mode eq 'create-session') {
        my ($tolerance, $retention) = @ARGV;
        die "invalid heartbeat tolerance\n" unless ($tolerance // '') =~ /\A\d+(?:\.\d+)?\z/;
        die "invalid operation retention\n" unless ($retention // '') =~ /\A\d+(?:\.\d+)?\z/;

        require File::Temp;
        require JSON::PP;
        my $request = read_message(\*STDIN);
        die "invalid session token\n" unless ($request->{token} // '') =~ /\A[a-f0-9]{64}\z/;
        my $session = File::Temp::tempdir('spooky-XXXXXXXX', DIR => '/tmp', CLEANUP => 0);
        chmod 0700, $session;
        open my $file, '>:raw', "$session/session.json" or die "cannot initialize session\n";
        print {$file} JSON::PP::encode_json({ token => $request->{token} });
        close $file;

        record_use();
        start_watcher($session, $tolerance, $retention);
        print "$session\n";
    } elsif ($mode eq 'close') {
        my $session = shift @ARGV;

        # 会话目录已经不在时算关闭成功：删除会话目录之前已确认其中的操作全部结束
        exit 0 if !lstat($session) && $! == ENOENT;

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
        $ENV{SSH_ASKPASS} = "$wrapper-askpass";
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
        (my $base = $wrapper) =~ s/-ssh-keygen\z//;
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
}

# 常驻通道只由单独启动的包装器打开，通道里的请求不能再开通道
if ($mode eq 'serve') {
    serve(@ARGV);
} else {
    dispatch($mode);
}
