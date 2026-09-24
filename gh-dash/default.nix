# gh-dash dashboard config, split into four work contexts.
# Repo lists in repos.nix are generated — see bin/scripts/gh-dash-repos.
{ pkgs, lib, username, ... }:
let
  repos = import ./repos.nix;

  # PR/issue sections take GitHub search syntax (org: works); notification
  # sections are client-side and only understand repo:owner/name.
  orgs = {
    SA = [ "structured-abstraction" ];
    Narrative = [ "narrative-io" ];
    BigGeo = [ "BigGeo-GIV" ];
    lichess = [ "lichess-org" "Lichess4545" ];
  };
  orgFilter = ctx: lib.concatMapStringsSep " " (o: "org:${o}") orgs.${ctx};
  repoFilter = ctx: lib.concatMapStringsSep " " (r: "repo:${r}") repos.${ctx};

  config = {
    prSections = [
      { title = "Mine"; filters = "is:open author:@me"; }
      { title = "SA"; filters = "is:open ${orgFilter "SA"}"; }
      { title = "Narrative"; filters = "is:open ${orgFilter "Narrative"} involves:@me"; }
      { title = "BigGeo"; filters = "is:open ${orgFilter "BigGeo"}"; }
      # lichess-org alone has hundreds of open PRs; scope it to yours.
      { title = "lichess"; filters = "is:open ${orgFilter "lichess"} involves:@me"; }
    ];

    issuesSections = [
      # Narrative runs reviews as issues in narrative-io/code-reviews, so both
      # halves get their own tab here rather than under PRs.
      { title = "Narrative: assigned"; filters = "is:open ${orgFilter "Narrative"} assignee:@me"; }
      { title = "Narrative: mine"; filters = "is:open ${orgFilter "Narrative"} author:@me"; }
      { title = "SA"; filters = "is:open ${orgFilter "SA"} assignee:@me"; }
      { title = "BigGeo"; filters = "is:open ${orgFilter "BigGeo"} assignee:@me"; }
      { title = "lichess"; filters = "is:open ${orgFilter "lichess"} assignee:@me"; }
    ];

    # Explicit order, not mapAttrsToList: attrset order is alphabetical and
    # these tabs should line up with the PR/issue ones.
    notificationsSections = map (ctx: {
      title = ctx;
      filters = "is:unread ${repoFilter ctx}";
    }) [ "SA" "Narrative" "BigGeo" "lichess" ];

    defaults = {
      view = "notifications";
      prsLimit = 20;
      issuesLimit = 20;
      notificationsLimit = 20;
      includeReadNotifications = false;
      refetchIntervalMinutes = 10;
      preview = { open = true; width = 0.5; };
      dateFormat = "relative";
    };

    # Where `o` (open in editor) looks for a local checkout.
    repoPaths = {
      "lichess-org/*" = "${homeDir}/personal-repos/lichess-org/*";
      "structured-abstraction/*" = "${homeDir}/work-repos/*";
      default = "${homeDir}/work-repos/*";
    };

    keybindings.prs = [
      # gh-enhance, the Actions companion — see ../gh-extensions.
      { key = "T"; command = "gh enhance -R {{.RepoName}} {{.PrNumber}}"; }
    ];
  };

  homeDir = "/home/${username}";
  yaml = (pkgs.formats.yaml { }).generate "gh-dash-config.yml" config;
in
{
  environment.etc."gh-dash/config.yml".source = yaml;

  system.activationScripts.ghDashConfig = {
    deps = [ "users" ];
    text = ''
      install -d -o ${username} -g users ${homeDir}/.config
      install -d -o ${username} -g users ${homeDir}/.config/gh-dash
      ln -sf /etc/gh-dash/config.yml ${homeDir}/.config/gh-dash/config.yml
      chown -h ${username}:users ${homeDir}/.config/gh-dash/config.yml
    '';
  };
}
