#!/bin/bash

# Global Constants
readonly DEFAULT_SYSTEM_VOLUME="Macintosh HD"
readonly DEFAULT_DATA_VOLUME="Macintosh HD - Data"

readonly DEFAULT_USER_FULL_NAME="Apple"
readonly DEFAULT_USER_NAME="Apple"
readonly DEFAULT_USER_PASSWORD=""

readonly APPLE_MDM_DOMAINS=("deviceenrollment.apple.com" "mdmenrollment.apple.com" "iprofiles.apple.com")

check_volume_existence() {
  local VOLUME_LABEL="$*"
  diskutil info "$VOLUME_LABEL" >/dev/null 2>&1
}

get_volume_name() {
  local VOLUME_TYPE="$1"

  # Getting the APFS Container Disk Identifier
  APFS_CONTAINER=$(diskutil list internal physical | grep 'Container' | awk -F'Container ' '{print $2}' | awk '{print $1}')
  # Getting the Volume Information
  VOLUME_INFO=$(diskutil ap list "$APFS_CONTAINER" | grep -A 5 "($VOLUME_TYPE)")
  # Extracting the Volume Name from the Volume Information
  VOLUME_NAME_LINE=$(echo "$VOLUME_INFO" | grep 'Name:')
  # Removing unnecessary characters to get the clean Volume Name
  VOLUME_NAME=$(echo "$VOLUME_NAME_LINE" | cut -d':' -f2 | cut -d'(' -f1 | xargs)

  echo "$VOLUME_NAME"
}

get_volume_path() {
  local DEFAULT_VOLUME=$1
  local VOLUME_TYPE=$2

  if check_volume_existence "$DEFAULT_VOLUME"; then
    echo "/Volumes/$DEFAULT_VOLUME"
  else
    local VOLUME_NAME
    VOLUME_NAME="$(get_volume_name "$VOLUME_TYPE")"
    echo "/Volumes/$VOLUME_NAME"
  fi
}

mount_volume() {
  local VOLUME_PATH=$1

  if [ ! -d "$VOLUME_PATH" ]; then
    diskutil mount "$VOLUME_PATH"
  fi
}

PS3="Please enter your choice: "
OPTIONS=("Mac MDM Bypass" "Check MDM Enrollment" "Reboot" "Exit")
select OPTION in "${OPTIONS[@]}"; do
  case ${OPTION} in
  "Mac MDM Bypass")
    # Get and mount
    echo "\nMounting system and data volumes"
    echo "Mounting system volume '${DEFAULT_SYSTEM_VOLUME}'"
    SYSTEM_VOLUME_PATH=$(get_volume_path "${DEFAULT_SYSTEM_VOLUME}" "System")
    mount_volume "${SYSTEM_VOLUME_PATH}"
    echo "Mounting data volume '${DEFAULT_DATA_VOLUME}'"
    DATA_VOLUME_PATH=$(get_volume_path "${DEFAULT_DATA_VOLUME}" "Data")
    mount_volume "${DATA_VOLUME_PATH}"

    echo "\nVerfying user existence"
    DSCL_PATH="${DATA_VOLUME_PATH}/private/var/db/dslocal/nodes/Default"
    LOCAL_USER_PATH="/Local/Default/Users"
    DEFAULT_USER_UID="501"
    if ! dscl -f "${DSCL_PATH}" localhost -list "${LOCAL_USER_PATH}" UniqueID | grep -q "\<${DEFAULT_USER_UID}\>"; then
      # Get user information
      echo "Provide new user information"
      read -rp "Full name (Default '${DEFAULT_USER_FULL_NAME}'): " USER_FULL_NAME
      USER_FULL_NAME="${USER_FULL_NAME:=${DEFAULT_USER_FULL_NAME}}"
      read -rp "User name (Default '${DEFAULT_USER_NAME}'): " USER_NAME
      USER_NAME="${username:=${DEFAULT_USER_NAME}}"
      read -rp "Password: '${DEFAULT_USER_PASSWORD}'" USER_PASSWORD
      USER_PASSWORD="${USER_PASSWORD:=${DEFAULT_USER_PASSWORD}}"

      # Create the user
      echo "Creating user '${USER_NAME}' path '${DATA_VOLUME_PATH}/Users/${USER_NAME}' for '${USER_FULL_NAME}'"
      dscl -f "${DSCL_PATH}" localhost -create "${LOCAL_USER_PATH}/${USER_NAME}"
      dscl -f "${DSCL_PATH}" localhost -create "${LOCAL_USER_PATH}/${USER_NAME}" UserShell "/bin/zsh"
      dscl -f "${DSCL_PATH}" localhost -create "${LOCAL_USER_PATH}/${USER_NAME}" RealName "${USER_FULL_NAME}"
      dscl -f "${DSCL_PATH}" localhost -create "${LOCAL_USER_PATH}/${USER_NAME}" UniqueID "${DEFAULT_USER_UID}"
      dscl -f "${DSCL_PATH}" localhost -create "${LOCAL_USER_PATH}/${USER_NAME}" PrimaryGroupID "20"
      mkdir "${DATA_VOLUME_PATH}/Users/${USER_NAME}"
      dscl -f "${DSCL_PATH}" localhost -create "${LOCAL_USER_PATH}/${USER_NAME}" NFSHomeDirectory "/Users/${USER_NAME}"
      dscl -f "${DSCL_PATH}" localhost -passwd "${LOCAL_USER_PATH}/${USER_NAME}" "${USER_PASSWORD}"
      dscl -f "${DSCL_PATH}" localhost -append "/Local/Default/Groups/admin" GroupMembership "${USER_NAME}"
    else
      echo "User already exist"
    fi

    # Block MDM hosts
    echo "\nBlocking MDM hosts"
    HOST_PATH="${SYSTEM_VOLUME_PATH}/etc/hosts"
    for DOMAIN in "${APPLE_MDM_DOMAINS[@]}"; do
      echo "0.0.0.0 ${DOMAIN}" >> ${HOST_PATH}
    done
    echo "Successfully blocked hosts"

    # Remove configuration profiles
    echo "\nRemove configuration profiles"
    CONFIGURATION_PROFILES_PATH="${SYSTEM_VOLUME_PATH}/var/db/ConfigurationProfiles/Settings"
    touch "${DATA_VOLUME_PATH}/private/var/db/.AppleSetupDone"
    rm -rf "${CONFIGURATION_PROFILES_PATH}/.cloudConfigHasActivationRecord"
    rm -rf "${CONFIGURATION_PROFILES_PATH}/.cloudConfigRecordFound"
    touch "${CONFIGURATION_PROFILES_PATH}/.cloudConfigProfileInstalled"
    touch "${CONFIGURATION_PROFILES_PATH}/.cloudConfigRecordNotFound"
    echo "Configuration profiles removed"

    # Remove the script once MDM Bypass finished
    rm "$(cd -- "$(dirname "${0}")" > /dev/null 2>&1; pwd -P)/${0}"
    echo "\nMac MDM Bypass finished"
    
    break
    ;;
    
  "Check MDM Enrollment")
    if [ ! -f /usr/bin/profiles ]; then echo "\nCheck MDM Enrollment should not be executed in recovery mode"; continue; fi
    if ! sudo profiles show -type enrollment >/dev/null 2>&1; then echo "Not enrolled";
    else echo "Enrolled"; fi
    ;;

  "Reboot") echo "\nRebooting"; reboot;;

  "Exit") echo "\nExiting"; exit;;

  *) echo "\nInvalid option: '${REPLY}'";;

  esac
done