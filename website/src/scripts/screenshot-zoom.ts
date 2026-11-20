/**
 * 截图的放大视图：点截图打开原尺寸的 `<dialog>`，点图、点背景或按关闭按钮关上，Esc 由浏览器处理。
 *
 * 用事件委托，页面里后来出现的截图同样适用。
 */
document.addEventListener('click', (event) => {
    if (!(event.target instanceof Element)) {
        return;
    }

    const opener = event.target.closest('.spooky-screenshot-open');

    if (opener) {
        opener.closest('.spooky-screenshot')?.querySelector('dialog')?.showModal();

        return;
    }

    const dialog = event.target.closest('dialog.spooky-screenshot-dialog');

    // 点在对话框本身（背景）或图上时关闭；关闭按钮由 `method="dialog"` 的表单处理
    if (
        dialog instanceof HTMLDialogElement &&
        (event.target === dialog || event.target instanceof HTMLImageElement)
    ) {
        dialog.close();
    }
});
