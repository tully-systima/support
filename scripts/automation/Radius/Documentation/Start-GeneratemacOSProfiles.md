# Start-GeneratemacOSProfiles Function

## Overview

This function generates macOS profiles (.mobileconfig files) for users in a JumpCloud environment. These profiles configure WiFi settings that use RADIUS authentication for secure network connectivity. macOS MDM profiles are the preferred way to load Radius certificates into the keychain, as they are deployed via the MDM trust chain, and therefore root certificates are deployed directly into the trusted secure enclave. The end result is that users are not required to manually approve per-user unsigned certs.

More information:

User certificate profile configuration:
https://developer.apple.com/documentation/devicemanagement/certificatepem

Root Certificate profile configuration:
https://developer.apple.com/documentation/devicemanagement/certificateroot

## How to Run

The function can be run in two ways:

1. **Interactive Mode (GUI)**: `Start-GeneratemacOSProfiles`
2. **Command Line (CLI)**: `Start-GeneratemacOSProfiles -type [All|New|ByUsername] [-username <username>] [-forceReplaceProfiles]`

## Process Steps

### 1. Certificate Key Password Verification

- Checks if the CA-Key password exists in environment variables
- If found, verifies the password works with the existing key file
- If not found or incorrect, prompts for the password via `Get-CertKeyPass`

### 2. Environment Setup

- Loads user data from the JSON file
- Creates necessary directories if they don't exist:
  - `UserProfiles`: Where generated profiles will be stored
  - `JCRadiusCert`: For certificate files
- Downloads JumpCloud Radius Root CA Certificate if needed

### 3. Prerequisite Checks

- Verifies all required certificate files exist:
  - Root CA Key
  - Root CA Certificate
  - UserCerts directory
- Exits with an error if any prerequisites are missing

### 4. Profile Generation

Depending on the selected option, one of the following processes occurs:

#### Option 1: Generate Profiles for New Users

- Identifies users who:
  - Have associated macOS systems
  - Don't have existing profiles
- Generates a profile for each eligible user
- Shows progress during generation

#### Option 2: Generate Profile by Username

- Prompts for username (in GUI mode) or uses provided username (in CLI mode)
- Verifies the user exists in JumpCloud
- Checks if the user has macOS systems
- If a profile already exists:
  - In GUI mode: Asks whether to replace it
  - In CLI mode: Uses the `-forceReplaceProfiles` parameter to determine action
- Generates profile for the specified user

#### Option 3: Generate Profiles for All Users

- Identifies all users with associated macOS systems
- In GUI mode: Confirms before proceeding as this may replace existing profiles
- Generates profiles for all eligible users
- Shows progress during generation

## Output

- `.mobileconfig` files are created in the `UserProfiles` directory
- Each profile is named `{username}-Radius-WiFi.mobileconfig`
- The updated user data is saved back to `users.json`

## Required Dependencies

The function relies on several other functions:
- `Generate-macOSProfiles`: Creates the actual profile files
- `Get-UserJsonData`: Retrieves user information
- `Test-UserFromHash`: Validates usernames
- `Show-macOSProfileMenu`: Displays the interactive menu
- `Show-RadiusProgress`: Displays progress during operations

## Note

Certificate files must be generated before running this function. This requires running `Generate-Cert.ps1` and `Generate-UserCert.ps1` first.
