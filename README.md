# Fork of Radius 2.0 to include macOS MDM profile generation

The purpose of this fork is to develop a system for distributing user assigned Radius certs as macOS .mobileconfig files
The goal is to use the MDM protocol to distribute per-user unsigned certs directly into the users keychain without requiring scripts,
and embed the root cert in the system keychain leveraging the MDM trust chain, so the unsigned root cert is inherently trusted.

Profiles can then be automatically associated to devices assigned to each user, removing the need for the user to manually approve the unsigned certificates,
and webhook script retries will no longer be nessecary.
