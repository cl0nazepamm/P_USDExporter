"""
Clone USD Tools - Unreal Editor Startup Registration
Drop this file into your Unreal project's Content/Python/ folder.
It auto-runs on editor startup and registers toolbar buttons.

Also place Clone_USD_CameraSequencer.py in Content/Python/.
Place your logo as Content/Python/CloneTools/powerusd_icon.png (20x20 recommended).
"""

import unreal
import os
import importlib


# -- Icon Setup ---------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ICON_PATH = os.path.join(SCRIPT_DIR, "CloneTools", "powerusd_icon.png")

def register_icon():
    """Register custom icon style if the logo file exists."""
    if not os.path.isfile(ICON_PATH):
        unreal.log_warning("CloneTools: Icon not found at {}. Using default.".format(ICON_PATH))
        return False

    style = unreal.SlateStyleSet("CloneToolsStyle")

    brush = unreal.SlateBrush()
    brush.set_editor_property("image_size", unreal.Vector2D(20.0, 20.0))
    brush.set_editor_property("resource_name", ICON_PATH)

    try:
        style.register()
        style.set_brush("CloneTools.CameraSequencer", brush)
        return True
    except Exception:
        return False


# -- Camera Sequencer Button --------------------------------------------------

def on_camera_sequencer_clicked(context):
    """Callback for the Camera Sequencer toolbar button."""
    try:
        import Clone_USD_CameraSequencer
        importlib.reload(Clone_USD_CameraSequencer)
        Clone_USD_CameraSequencer.run()
    except Exception as e:
        unreal.log_error("CloneTools: Camera Sequencer failed: {}".format(e))


def register_menu():
    """Add Clone Tools entries to the editor Tools menu."""
    menus = unreal.ToolMenus.get()

    # Add to Tools menu
    tools_menu = menus.find_menu("LevelEditor.MainMenu.Tools")
    if not tools_menu:
        unreal.log_warning("CloneTools: Could not find Tools menu.")
        return

    # Create a section for Clone Tools
    section_name = "CloneTools"
    tools_menu.add_section(section_name, section_label="Clone Tools")

    # Camera Sequencer entry
    entry = unreal.ToolMenuEntry(
        name="CloneTools_CameraSequencer",
        type=unreal.MultiBlockType.MENU_ENTRY
    )
    entry.set_label("Build Camera Cuts from USD")
    entry.set_tool_tip("Reads _camera_sequence.json and builds Camera Cut Track in Sequencer.")
    entry.set_string_command(
        type=unreal.ToolMenuStringCommandType.PYTHON,
        custom_type="",
        string=(
            "import Clone_USD_CameraSequencer, importlib; "
            "importlib.reload(Clone_USD_CameraSequencer); "
            "Clone_USD_CameraSequencer.run()"
        )
    )

    tools_menu.add_menu_entry(section_name, entry)

    # Rebuild menus
    menus.refresh_all_widgets()

    unreal.log("CloneTools: Registered 'Build Camera Cuts from USD' in Tools menu.")


# -- Toolbar Button -----------------------------------------------------------

def register_toolbar():
    """Add a toolbar button to the level editor toolbar."""
    menus = unreal.ToolMenus.get()

    toolbar = menus.find_menu("LevelEditor.LevelEditorToolBar.PlayToolBar")
    if not toolbar:
        # Try alternative toolbar name
        toolbar = menus.find_menu("LevelEditor.LevelEditorToolBar.User")
    if not toolbar:
        unreal.log_warning("CloneTools: Could not find toolbar. Menu entry still available under Tools.")
        return

    section_name = "CloneTools"
    toolbar.add_section(section_name, section_label="Clone")

    entry = unreal.ToolMenuEntry(
        name="CloneTools_CameraSequencer_Toolbar",
        type=unreal.MultiBlockType.TOOL_BAR_BUTTON
    )
    entry.set_label("Cam Cuts")
    entry.set_tool_tip("Clone USD: Build Camera Cut Track from _camera_sequence.json")
    entry.set_string_command(
        type=unreal.ToolMenuStringCommandType.PYTHON,
        custom_type="",
        string=(
            "import Clone_USD_CameraSequencer, importlib; "
            "importlib.reload(Clone_USD_CameraSequencer); "
            "Clone_USD_CameraSequencer.run()"
        )
    )

    toolbar.add_menu_entry(section_name, entry)
    menus.refresh_all_widgets()

    unreal.log("CloneTools: Registered toolbar button 'Cam Cuts'.")


# -- Startup ------------------------------------------------------------------

def startup():
    register_icon()
    register_menu()
    register_toolbar()
    unreal.log("CloneTools: Startup complete.")


startup()
