const { app, BrowserWindow, Menu } = require('electron');
const path = require('path');
const isDev = !app.isPackaged;

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1360,
    height: 800,
    minWidth: 1024,
    minHeight: 768,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: !isDev,
    },
    titleBarOverlay: {
      color: '#ffffff',
      symbolColor: '#74b9ff',
      height: 40
    }
  });

  const startUrl = isDev ? 'http://localhost:3000' : `file://${path.join(__dirname, '../out/index.html')}`;
  mainWindow.loadURL(startUrl);

  if (isDev) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Create menu
  // const template = [
  //   {
  //     label: 'File',
  //     submenu: [
  //       {
  //         label: 'New Order',
  //         accelerator: 'CmdOrCtrl+N',
  //         click: () => {
  //           mainWindow.webContents.send('new-order');
  //         }
  //       },
  //       { type: 'separator' },
  //       {
  //         role: 'quit'
  //       }
  //     ]
  //   },
  //   {
  //     label: 'Edit',
  //     submenu: [
  //       { role: 'undo' },
  //       { role: 'redo' },
  //       { type: 'separator' },
  //       { role: 'cut' },
  //       { role: 'copy' },
  //       { role: 'paste' }
  //     ]
  //   },
  //   {
  //     label: 'View',
  //     submenu: [
  //       { role: 'reload' },
  //       { role: 'forceReload' },
  //       { role: 'toggleDevTools' },
  //       { type: 'separator' },
  //       { role: 'resetZoom' },
  //       { role: 'zoomIn' },
  //       { role: 'zoomOut' },
  //       { type: 'separator' },
  //       { role: 'togglefullscreen' }
  //     ]
  //   },
  //   {
  //     label: 'Window',
  //     submenu: [
  //       { role: 'minimize' },
  //       { role: 'close' }
  //     ]
  //   }
  // ];

  // const menu = Menu.buildFromTemplate(template);
  // Menu.setApplicationMenu(menu);
  Menu.setApplicationMenu(null);
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});