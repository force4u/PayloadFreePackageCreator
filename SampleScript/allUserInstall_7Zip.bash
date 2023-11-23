#!/bin/bash
#com.cocolog-nifty.quicktimer.icefloe
#ユーザーディレクトリ直下
# $HOME/binに7-zipのバイナリをインストールする
#	全ローカルユーザー対象
########################################
###管理者インストールしているか？チェック
USER_WHOAMI=$(/usr/bin/whoami)
/bin/echo "実行したユーザーは：$USER_WHOAMI"
if [ "$USER_WHOAMI" != "root" ]; then
	/bin/echo "このスクリプトを実行するには管理者権限が必要です。"
	/bin/echo "sudo で実行してください"
	### path to me
	SCRIPT_PATH="${BASH_SOURCE[0]}"
	/bin/echo "/usr/bin/sudo \"$SCRIPT_PATH\""
	/bin/echo "↑を実行してください"
	exit 1
else
	###実行しているユーザー名
	CURRENT_USER=$(/bin/echo "$HOME" | /usr/bin/awk -F'/' '{print $NF}')
	/bin/echo "実行ユーザー：" "$CURRENT_USER"
fi
###ログイン名ユーザー名※Visual Studio Codeの出力パネルではrootになる設定がある
LOGIN_NAME=$(/usr/bin/logname)
/bin/echo "ログイン名：$LOGIN_NAME"
###UID
USER_NAME=$(/usr/bin/id -un)
/bin/echo "ユーザー名:$USER_NAME"
###SUDOUSER
SUDO_ER=$(/bin/echo "$SUDO_USER")
if [ -z "$SUDO_ER" ]; then
	/bin/echo "ROOTユーザーで実行"
else
	/bin/echo "SUDO_USER: $SUDO_USER"
fi
###USER
CURRENT_USER=$(/bin/echo "$USER")
/bin/echo "CURRENT_USER: $CURRENT_USER"
###実行しているユーザー名
USER_HOME_NAME=$(/bin/echo "$HOME" | /usr/bin/awk -F'/' '{print $NF}')
/bin/echo "USER_HOME_NAME : " "$USER_HOME_NAME"
###コンソールユーザー CONSOLE_USERはFinderでログインしていないと出ない
CONSOLE_USER=$(/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }')
if [ -z "$CONSOLE_USER" ]; then
	/bin/echo "コンソールユーザーが無い=電源入れてログインウィンドウ状態"
else
	/bin/echo "コンソールユーザー：" "$CONSOLE_USER"
fi
########################################
##OSのバージョンを取得
PLIST_PATH="/System/Library/CoreServices/SystemVersion.plist"
STR_OS_VER=$(/usr/bin/defaults read "$PLIST_PATH" ProductVersion)
/bin/echo "OS VERSION ：" "$STR_OS_VER"
STR_MAJOR_VERSION="${STR_OS_VER%%.*}"
/bin/echo "STR_MAJOR_VERSION ：" "$STR_MAJOR_VERSION"
STR_MINOR_VERSION="${STR_OS_VER#*.}"
/bin/echo "STR_MINOR_VERSION ：" "$STR_MINOR_VERSION"
########################################
##デバイス
#起動ディスクの名前を取得する
STR_CHECK_DIR_PATH="/Users/Shared/Documents/Apple/IOPlatformUUID"
/bin/mkdir -p "$STR_CHECK_DIR_PATH"
/bin/chmod 775 "$STR_CHECK_DIR_PATH"
/usr/bin/chgrp staff "$STR_CHECK_DIR_PATH"
/usr/bin/touch "$STR_CHECK_DIR_PATH/com.apple.diskutil.plist"
/usr/sbin/diskutil info -plist / >"$STR_CHECK_DIR_PATH/com.apple.diskutil.plist"
STARTUPDISK_NAME=$(/usr/bin/defaults read "$STR_CHECK_DIR_PATH/com.apple.diskutil.plist" VolumeName)
/bin/echo "ボリューム名：" "$STARTUPDISK_NAME"
#デバイスUUID
/usr/bin/touch "$STR_CHECK_DIR_PATH/com.apple.ioreg.plist"
/usr/sbin/ioreg -c IOPlatformExpertDevice -a >"$STR_CHECK_DIR_PATH/com.apple.ioreg.plist"
STR_DEVICE_UUID=$(/usr/sbin/ioreg -c IOPlatformExpertDevice | grep IOPlatformUUID | awk -F'"' '{print $4}')
/bin/echo "デバイスUUID: " "$STR_DEVICE_UUID"

########################################
###ローカルのユーザーアカウントを取得
DSCL_RESULT=$(/usr/bin/dscl localhost -list /Local/Default/Users PrimaryGroupID | /usr/bin/awk '$2 == 20 { print $1 }')
###リストにする
read -d '\\n' -r -a LIST_USER <<<"$DSCL_RESULT"
###リスト内の項目数
NUM_CNT=${#LIST_USER[@]}
/bin/echo "ユーザー数：" "$NUM_CNT"
########################################
###各ユーザーの最終ログアウト日
for ITEM_LIST in "${LIST_USER[@]}"; do
	STR_CHECK_File_PATH="/Users/${ITEM_LIST}/Library/Preferences/ByHost/com.apple.loginwindow.$STR_DEVICE_UUID.plist"
	STR_LAST_LOGOUT=$(/usr/bin/sudo -u "${ITEM_LIST}" /usr/bin/stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$STR_CHECK_File_PATH")
	/bin/echo "ユーザー$ITEM_LIST の最終ログアウト日: " "$STR_LAST_LOGOUT"
done
########################################
###ダウンロード起動時に削除する項目
for ITEM_LIST in "${LIST_USER[@]}"; do
	USER_TEMP_DIR=$(/usr/bin/sudo -u "${ITEM_LIST}" /usr/bin/mktemp -d)
	/bin/echo "${ITEM_LIST}	:テンポラリ・ディレクトリ：" "$USER_TEMP_DIR"
done

############################################################
############################################################
###ダウンロードURL
STR_URL="https://www.7-zip.org/a/7z2301-mac.tar.xz"
###ファイル名を取得
DL_FILE_NAME=$(/usr/bin/curl -s -L -I -o /dev/null -w '%{url_effective}' "$STR_URL" | /usr/bin/rev | /usr/bin/cut -d'/' -f1 | /usr/bin/rev)
/bin/echo "DL_FILE_NAME:$DL_FILE_NAME"
##
STR_UUID=$(/usr/bin/uuidgen)
STR_SAVE_DIR_PATH="/private/tmp/$STR_UUID"
/bin/mkdir -p "$STR_SAVE_DIR_PATH"
/bin/chmod 777 "$STR_SAVE_DIR_PATH"

###ダウンロード
if ! /usr/bin/curl -L -o "$STR_SAVE_DIR_PATH/$DL_FILE_NAME" "$STR_URL" --connect-timeout 20; then
	/bin/echo "ファイルのダウンロードに失敗しました HTTP1.1で再トライします"
	if ! /usr/bin/curl -L -o "$STR_SAVE_DIR_PATH/$DL_FILE_NAME" "$STR_URL" --http1.1 --connect-timeout 20; then
		/bin/echo "ファイルのダウンロードに失敗しました"
		exit 1
	fi
fi
##全ユーザー実行可能にしておく
/bin/chmod 755 "$STR_SAVE_DIR_PATH/$DL_FILE_NAME"
/bin/echo "ダウンロードOK"
/bin/mkdir -p "$STR_SAVE_DIR_PATH/7zip/"
############################################################
####解凍
##	/usr/bin/bsdtar -xzf "$USER_TEMP_DIR/$DL_FILE_NAME" -C "$USER_TEMP_DIR/7zip" --strip-components=1
/usr/bin/bsdtar -xzf "$STR_SAVE_DIR_PATH/$DL_FILE_NAME" -C "$STR_SAVE_DIR_PATH/7zip"
sleep 2
/bin/echo "解凍OK"
####移動
for ITEM_LIST in "${LIST_USER[@]}"; do
	/usr/bin/sudo -u "${ITEM_LIST}" /bin/mkdir -p "/Users/${ITEM_LIST}/bin/7zip"
	/usr/bin/sudo -u "${ITEM_LIST}" /bin/chmod 700 "/Users/${ITEM_LIST}/bin"
	/usr/bin/ditto "$STR_SAVE_DIR_PATH/7zip" "/Users/${ITEM_LIST}/bin/7zip"
	/usr/sbin/chown -Rf "${ITEM_LIST}" "/Users/${ITEM_LIST}/bin/7zip"
	/usr/bin/chgrp -Rf admin "/Users/${ITEM_LIST}/bin/7zip"
	/bin/echo "${ITEM_LIST} インストールOK"
done
####終了

exit 0
