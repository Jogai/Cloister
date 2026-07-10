# Cloister Fish Configuration
set -gx PATH /home/monk/.local/bin /usr/local/bin /usr/bin /bin $PATH
set -gx HOME /home/monk
set -gx LANG C.UTF-8
set -gx LC_ALL C.UTF-8
set -gx VFOX_HOME /home/monk/.version-fox
set -gx NPM_CONFIG_PREFIX /home/monk/.npm-global

# Initialize vfox if available
if type -q vfox
    vfox activate fish | source
end

# Show the Cloister banner once per interactive terminal / zellij pane
if status is-interactive
    set -l __banner_marker /tmp/.cloister-banner-(tty | string replace -a / _)
    if not test -e $__banner_marker
        cloister-banner
        touch $__banner_marker 2>/dev/null
    end
end
