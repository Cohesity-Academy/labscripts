@echo off
net use S: \\app-server-1\AppShares /user:acme\administrator Acme123!
net use H: \\isilon\HomeDrive /user:acme\administrator Acme123!
net use G: \\isilon\GroupDrive /user:acme\administrator Acme123!