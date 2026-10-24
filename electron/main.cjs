const {
  app,
  BrowserWindow,
  Menu,
  session,
  shell,
  dialog,
} = require("electron");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const development = !app.isPackaged;
const entry = development
  ? "http://127.0.0.1:5173"
  : pathToFileURL(path.join(__dirname, "../dist/index.html")).href;
const apiOrigin = development
  ? "http://127.0.0.1:54321"
  : JSON.parse(
      readFileSync(path.join(__dirname, "../dist/runtime.json"), "utf8"),
    ).apiOrigin;
app.enableSandbox();
function createWindow() {
  const win = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 900,
    minHeight: 600,
    title: "ClinicOS",
    backgroundColor: "#f5f6f8",
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      devTools: development,
    },
  });
  win.webContents.setWindowOpenHandler(({ url }) => {
    try {
      const target = new URL(url);
      if (
        target.origin === apiOrigin &&
        target.pathname.startsWith("/storage/v1/object/sign/")
      )
        void shell.openExternal(url);
    } catch {}
    return { action: "deny" };
  });
  win.webContents.on("will-navigate", (event, url) => {
    if (
      new URL(url).origin !== new URL(entry).origin ||
      (!development && !url.startsWith(entry.split("#")[0]))
    )
      event.preventDefault();
  });
  win.webContents.session.setPermissionRequestHandler(
    (_webContents, _permission, callback) => callback(false),
  );
  win.webContents.session.setPermissionCheckHandler(() => false);
  void win.loadURL(entry);
  Menu.setApplicationMenu(
    Menu.buildFromTemplate([
      { role: "appMenu" },
      { role: "fileMenu" },
      { role: "editMenu" },
      {
        label: "View",
        submenu: [
          { role: "resetZoom" },
          { role: "zoomIn" },
          { role: "zoomOut" },
          { role: "togglefullscreen" },
          ...(development ? [{ role: "toggleDevTools" }] : []),
        ],
      },
      { role: "windowMenu" },
    ]),
  );
}
app.whenReady().then(() => {
  session.defaultSession.webRequest.onHeadersReceived((details, callback) =>
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        "Content-Security-Policy": [
          "default-src 'self'; script-src 'self'" +
            (development ? " 'unsafe-inline'" : "") +
            `; style-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self' ${apiOrigin}${development ? " ws://127.0.0.1:5173" : ""}; img-src 'self' data: blob: ${apiOrigin}; object-src 'none'; base-uri 'self'; form-action 'self'`,
        ],
      },
    }),
  );
  createWindow();
  if (app.isPackaged && process.env.CLINICOS_UPDATE_URL) {
    const updateUrl = new URL(process.env.CLINICOS_UPDATE_URL);
    if (updateUrl.protocol !== "https:")
      throw new Error("Update feed must use HTTPS");
    const { autoUpdater } = require("electron-updater");
    autoUpdater.setFeedURL({ provider: "generic", url: updateUrl.href });
    autoUpdater.autoInstallOnAppQuit = true;
    const reportUpdateFailure = () => {
      dialog.showErrorBox(
        "ClinicOS update unavailable",
        "The update could not be verified or downloaded. Your installed version is unchanged. Contact your system administrator to restore updates.",
      );
    };
    autoUpdater.on("error", reportUpdateFailure);
    void autoUpdater.checkForUpdates().catch(() => {
      /* electron-updater emits the error event handled above. */
    });
  }
  app.on("activate", () => {
    if (!BrowserWindow.getAllWindows().length) createWindow();
  });
});
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
