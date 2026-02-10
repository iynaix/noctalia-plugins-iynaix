import QtQuick
import Quickshell.Io
import qs.Services.UI

Item {
  property var pluginApi: null

  IpcHandler {
    target: "plugin:projects"
    function toggle() {
      pluginApi.withCurrentScreen(screen => {
        var searchText = PanelService.getLauncherSearchText(screen);
        var isInProjectsMode = searchText.startsWith(">pj") || searchText.startsWith(">projects ");
        if (!PanelService.isLauncherOpen(screen)) {
          PanelService.openLauncherWithSearch(screen, ">pj ");
        } else if (isInProjectsMode) {
          PanelService.closeLauncher(screen);
        } else {
          PanelService.setLauncherSearchText(screen, ">pj ");
        }
      });
    }
  }
}
