Flatpak App Installer v1.3

Flatpak App Installer v1.3 is a Bash script designed to simplify and streamline the process of replacing applications installed via traditional package managers like apt or snap with their Flatpak equivalents. It ensures a clean and conflict-free application environment, particularly for systems like Kubuntu

Key Features

    Automated Replacement:
        Automatically detects and removes applications installed via apt or snap.
        Installs their Flatpak equivalents from the Flathub repository.

    Flatpak Setup:
        Ensures that Flatpak is installed and the Flathub repository is added to the system if not already present.

    Retry Mechanism:
        Automatically retries failed Flatpak installations

    Selective Installation:
        Supports the --install-only-missing flag, allowing users to skip Flatpak installations for applications already installed.

    Comprehensive Reporting:
        Provides a detailed summary of all actions performed, including successful installations, failures, and skipped applications.

Applications Managed

The script targets the following applications, replacing their apt or snap versions with Flatpak versions:

    Firefox
    Grsync (apt version)
    Gwenview
    Kate (this might be removed)
    Krita
    Okular
    PCSX2
    RetroArch
    Spectacle - removed 
    Steam
    VLC
    Yakuake
    qBittorrent
    
    Benefits

    Consistency:
        Flatpak ensures a consistent and sandboxed application environment, reducing dependency conflicts.

    Cross-Distro Compatibility:
        Leverages the Flathub repository to maintain uniform application versions across distributions.

    Conflict Resolution:
        Resolves potential conflicts between applications installed via apt, snap, and Flatpak.

    User Control:
        Optional flags provide flexibility for users to tailor the script’s behavior to their needs.


Run the Script: Ensure the script is executable:

chmod +x flatpak_app_installer_v1.3.sh
./flatpak_app_installer_v1.3.sh

Optional Flag: Use --install-only-missing to skip re-installation of Flatpaks already present:

    ./flatpak_app_installer_v1.3.sh --install-only-missing

Contributions

Contributions are welcome! If you encounter issues or have feature requests, feel free to open an issue or submit a pull request.
