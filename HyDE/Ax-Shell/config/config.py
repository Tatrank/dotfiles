import os
import sys
from pathlib import Path


def _configure_sys_path_for_direct_execution():
    """
    Ajusta sys.path si este script se ejecuta directamente,
    para asegurar que las importaciones relativas dentro del paquete 'config' funcionen.
    Esto permite ejecutar `python config/config.py` desde cualquier directorio.
    """
    if __name__ == "__main__":
        current_file_dir = Path(__file__).resolve().parent
        project_root = current_file_dir.parent

        if str(project_root) not in sys.path:
            sys.path.insert(0, str(project_root))

_configure_sys_path_for_direct_execution()

import shutil

from fabric import Application

if __name__ == "__main__" and (__package__ is None or __package__ == ''):
    from config.data import APP_NAME, APP_NAME_CAP
    from config.settings_gui import HyprConfGUI
    from config.settings_utils import load_bind_vars
else:
    from .data import APP_NAME, APP_NAME_CAP
    from .settings_gui import HyprConfGUI
    from .settings_utils import load_bind_vars


def open_config():
    """
    Entry point for opening the configuration GUI using Fabric Application.
    """
    load_bind_vars()

    show_lock_checkbox = False


    show_idle_checkbox = False

 

    app = Application(f"{APP_NAME}-settings")
    window = HyprConfGUI(
        show_lock_checkbox=show_lock_checkbox,
        show_idle_checkbox=show_idle_checkbox,
        application=app,
        on_destroy=lambda *_: app.quit()
    )
    app.add_window(window)

    window.show_all()
    app.run()


if __name__ == "__main__":
    open_config()
