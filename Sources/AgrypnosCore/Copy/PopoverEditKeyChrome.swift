/// Hidden Edit menu owns Cmd+C/V/X/A. A popover local monitor that
/// also sendAction(paste) inserts the clipboard twice.
public enum PopoverEditKeyChrome: Sendable {
    public static let sendsEditActionsFromLocalMonitor = false
    public static let menuCut = "x"
    public static let menuCopy = "c"
    public static let menuPaste = "v"
    public static let menuSelectAll = "a"
}
