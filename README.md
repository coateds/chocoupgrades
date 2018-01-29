# chocoupgrades

Chef demonstrator for using custom resources

This cookbook adds a logging function to select resources. The original intent was to run automatic chocolatey package upgrades and log each upgrade occurance to an installation log. The trick was to find a way to customize the logged message with the name of the pakcage being upgraded. It was not possible to use a single attribute fed to a function for this because of the 2 phases of a Chef client run.

That is, the attribute(s) would get set in the first phase of the run and the chocolatey_package would install or upgrade during the second phase. This meant that two instances of an install in the same Chef client run would suffer and overwrite problem.

