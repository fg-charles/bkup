# Copyright 2024 Charles Faisandier
# This file is part of bkup.
# bkup is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.
# bkup is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# bkup. If not, see <https://www.gnu.org/licenses/>. 
# ###############################################################################

$bkup_a config --unset core.bare
$bkup_a config core.worktree /
$bkup_a config diff.ignoreSubmodules none
$bkup_a config status.showUntrackedFiles false
$bkup_a config status.submoduleSummary true
$bkup_a config push.autoSetupRemote true
$bkup_a config submodule.recurse true
$bkup_a config push.autoSetupRemote true
$bkup_a config pull.ff only
