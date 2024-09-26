# Macbook MDM Bypass

This project focuses on developing a tool that can bypass Apple's Mobile Device Management (MDM) system. MDM is commonly
used by organizations to manage iOS and macOS devices, enforcing security policies, remote control, and custom
configurations. The bypass tool allows users to regain control over their devices by circumventing MDM restrictions,
effectively restoring full functionality and privacy to the user while maintaining device usability.

**Note: This project is for educational purposes only and should not be used for illegal or unethical activities.**

# Steps

1. Reinstall macOS on the device locked by MDM.
2. Boot into recovery mode, open Safari, and go to: https://github.com/EightAugusto/macbook-mdm-bypass
3. Copy the following script:
    ```
    curl https://raw.githubusercontent.com/EightAugusto/macbook-mdm-bypass/refs/heads/develop/macbook-mdm-bypass.sh -o macbook-mdm-bypass.sh; \
    chmod +x macbook-mdm-bypass.sh; \
    sh macbook-mdm-bypass.sh;
    ```
4. Close Safari.
5. Open Utilities > Terminal, paste the command (Command + V), and run the script.
6. Follow the steps in the interactive script (Interactive inputs should not contain whitespaces).
7. Reboot (This will create a new user based on the details provided in the script).

**Note: Do not reinstall or erase macOS again, as the device will be locked once more.**