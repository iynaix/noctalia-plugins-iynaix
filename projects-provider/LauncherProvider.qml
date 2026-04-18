import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  // Plugin API provided by PluginService
  property var pluginApi: null

  // Provider metadata
  property string name: "Projects"
  property var launcher: null
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: false

  readonly property list<string> projectDirs: pluginApi?.pluginSettings?.projectDirs ||
                                                pluginApi?.manifest?.metadata?.defaultSettings?.projectDirs ||
                                                ["~/Documents"]
  readonly property string openCommand: pluginApi?.pluginSettings?.openCommand ||
                                       pluginApi?.manifest?.metadata?.defaultSettings?.openCommand ||
                                       "nvim %s"

  property var projects: []
  property bool loading: false

  // Load projects on init
  function init() {
    if (pluginApi && pluginApi.pluginDir && !loading) {
      loading = true;
      projectsScanner.running = true;
    }
  }

  Process {
    id: projectsScanner
    command: [
      "sh", "-c",
      "find " + root.projectDirs.map(function (projectDir) {
        return '"' + projectDir.replace("~", "$HOME") + '"';
      }).join(" ") + " -mindepth 1 -maxdepth 1 -type d -exec test -d \"{}/.git\" \\; -print 2>/dev/null | sort -f"
    ]
    running: false
    stdout: StdioCollector {}

    onExited: function (exitCode) {
      if (exitCode !== 0) {
        root.loading = false;
        Logger.e("ProjectsProvider", "Scan failed with code: " + exitCode);
        return;
      }

      var output = String(stdout.text || "");
      var projectDirs = [];
      output.trim().split('\n').forEach(function (dir) {
        var proj = dir.split("/").pop();

        if (proj.length > 0) {
          projectDirs.push({name: proj, directory: dir});
        };
      });

      root.projects = projectDirs;
      root.loading = false;

      Logger.i("ProjectsProvider", "Projects loaded: ", root.projects.length, "entries");
    }
  }

  // Check if this provider handles the command
  function handleCommand(searchText) {
    return searchText.startsWith(">pj") || searchText.startsWith(">projects ");
  }

  // Return available commands when user types ">"
  function commands() {
    return [{
      "name": ">pj",
      "description": "Browse and open projects in the editor",
      "icon": "edit",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        launcher.setSearchText(">pj ");
      }
    }];
  }

  // Get search results
  function getResults(searchText) {
    if (!searchText.startsWith(">pj") && !searchText.startsWith(">projects")) {
      return [];
    }

    if (loading) {
      return [{
        "name": "Loading...",
        "description": "Loading projects...",
        "icon": "refresh",
        "isTablerIcon": true,
        "isImage": false,
        "onActivate": function() {
          root.init();
        }
      }];
    }

    var query = searchText.replace(/^>pj/, "").replace(/^>projects/, "").trim();
    var results = [];
    var count = 0;
    var i = 0;

    if (query === "") {
      for (i = 0; i < projects.length && count < 100; i++) {
        var res = projects[i];
        results.push(formatProjectEntry(res.name, res.directory));
        count++;
      }
    } else {
      const fuzzyResults = FuzzySort.go(query, projects, {
                                          "keys": ["name"],
                                          "threshold": -1000,
                                          "limit": 100,
                                        });

      for (i = 0; i < fuzzyResults.length; i++) {
        let res = fuzzyResults[i].obj;
        results.push(formatProjectEntry(res.name, res.directory));
        count++;
      }
    }

    return results;
  }

  // Format a project entry for the results list
  function formatProjectEntry(project, directory) {
    return {
      "name": project,
      "description": null,
      "icon": "folder",
      "isTablerIcon": true,
      "isImage": false,
      "hideIcon": false,         // No icon needed in list view
      "singleLine": true,
      "onActivate": function() {
        let cmd = root.openCommand.replace('"%s"', "'" + directory + "'").replace("%s", "'" + directory + "'");

        Quickshell.execDetached(["sh", "-c", cmd]);
        launcher.close();
      }
    };
  }
}
