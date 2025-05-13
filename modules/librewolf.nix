{ ... }:

{
  home.sessionVariables = {
    MOZ_USE_XINPUT2 = "1";
    MOZ_ENABLE_WAYLAND = "1 firefox";
  };

  #home.packages = with pkgs; [ firefox-bin ];

  programs.librewolf = {
    enable = true;
    /* ---- PREFERENCES ---- */
    # Check about:config for options.
    settings = { 
      "webgl.disabled" = false;
      "privacy.clearOnShutdown.history" = false;
      "privacy.clearOnShutdown.cookies" = false;
      "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;

      "browser.contentblocking.category" = "strict";
      "extensions.pocket.enabled" = false;
      "extensions.screenshots.disabled" = true;
      "browser.topsites.contile.enabled" = false;
      "browser.formfill.enable" = true;
      "browser.search.suggest.enabled" = true;
      "browser.search.suggest.enabled.private" = false;
      "browser.urlbar.suggest.searches" = true;
      "browser.urlbar.showSearchSuggestionsFirst" = false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
      "browser.newtabpage.activity-stream.feeds.snippets" = false;
      "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
      "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = false;
      "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = false;
      "browser.newtabpage.activity-stream.section.highlights.includeVisited" = false;
      "browser.newtabpage.activity-stream.showSponsored" = false;
      "browser.newtabpage.activity-stream.system.showSponsored" = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "network.security.ports.banned.override" = "1-10000";
      #"widget.use-xdg-desktop-portal.file-picker" = 1;
    };

    # profiles.maixnor = {
    #   id = 0;
    #   name = "maixnor";
    #   isDefault = true;
    #   extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
    #     darkreader
    #     bitwarden
    #     ublock-origin
    #     decentraleyes
    #     privacy-badger
    #     youtube-recommended-videos
    #     vimium
    #     simple-translate
    #     add-custom-search-engine
    #     gesturefy
    #     side-view
    #     bionic-reader
    #     tranquility-1
    #     wakatimes
    #   ];
    # };

    # policies = {
    #   DisableTelemetry = true;
    #   DisableFirefoxStudies = true;
    #   EnableTrackingProtection = {
    #     Value = true;
    #     Locked = true;
    #     Cryptomining = true;
    #     Fingerprinting = true;
    #   };
    #   DisablePocket = true;
    #   DisableFirefoxAccounts = false;
    #   DisableAccounts = false;
    #   DisableFirefoxScreenshots = false;
    #   OverrideFirstRunPage = "";
    #   OverridePostUpdatePage = "";
    #   DontCheckDefaultBrowser = true;
    #   DisplayBookmarksToolbar = "newtab"; # alternatives: "always" or "newtab"
    #   DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
    #   SearchBar = "unified"; # alternative: "separate"
    # };

  };

}
