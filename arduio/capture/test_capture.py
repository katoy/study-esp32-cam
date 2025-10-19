import serial
import requests
import time
import re

# Pillowライブラリのインポートを試みる
try:
    from PIL import Image
except ImportError:
    print("エラー: Pillowライブラリが見つかりません。")
    print("画像検証のために、Pillowをインストールしてください。")
    print("pip install Pillow")
    exit(1)

# --- 設定 ---
SERIAL_PORT = "/dev/cu.usbserial-1130"
BAUD_RATE = 115200
TIMEOUT = 20  # IPアドレス取得のタイムアウト（秒）
WIFI_SSID = "TP-Link_C390"
# Arduinoコードで設定された期待する解像度 (PSRAM搭載ESP32-CAMのデフォルト)
EXPECTED_RESOLUTION = (800, 600)

def get_ip_from_serial():
    """シリアルポートを監視し、ESP32-CAMのIPアドレスを取得する"""
    print(f"シリアルポート {SERIAL_PORT} を開いています...")
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
    except serial.SerialException as e:
        print(f"エラー: シリアルポート {SERIAL_PORT} を開けません。")
        print(f"詳細: {e}")
        print("ESP32-CAMが接続されているか、ポート名が正しいか確認してください。")
        return None

    print(f"ESP32-CAMの起動とWi-Fi({WIFI_SSID})への接続を待っています... (最大{TIMEOUT}秒)")

    start_time = time.time()
    ip_address = None

    while time.time() - start_time < TIMEOUT:
        try:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            if line:
                print(f"  [SERIAL] {line}")

            # IPアドレスの正規表現を検索
            match = re.search(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', line)
            if match:
                ip_address = match.group(1)
                print(f"✅ IPアドレスが見つかりました: {ip_address}")
                break
        except Exception as e:
            print(f"シリアル読み込み中にエラーが発生しました: {e}")
            # ループを継続

    ser.close()

    if not ip_address:
        print(f"❌ {TIMEOUT}秒以内にIPアドレスを取得できませんでした。")
        print("  - ESP32-CAMがリセットされ、正しく起動しているか確認してください。")
        print(f"  - Wi-Fi SSID '{WIFI_SSID}' が正しいか、電波状況が良いか確認してください。")

    return ip_address

def test_capture(ip_address):
    """撮影エンドポイントをテストする"""
    url = f"http://{ip_address}/capture"
    output_filename = "capture_test_output.jpg"
    print(f"\n--- キャプチャテスト開始 ---")
    print(f"GETリクエストを {url} に送信します...")

    try:
        response = requests.get(url, timeout=10)

        # 1. ステータスコードの検証
        print(f"  ステータスコード: {response.status_code}")
        assert response.status_code == 200, f"期待値 200, 実際値 {response.status_code}"
        print("  ✅ ステータスコードが200 OKです。")

        # 2. Content-Typeの検証
        content_type = response.headers.get('Content-Type')
        print(f"  Content-Type: {content_type}")
        assert content_type == 'image/jpeg', f"期待値 'image/jpeg', 実際値 '{content_type}'"
        print("  ✅ Content-Typeが 'image/jpeg' です。")

        # 3. 画像データサイズの検証 (SVGAなのでサイズ下限を上げる)
        image_size = len(response.content)
        print(f"  受信データサイズ: {image_size} bytes")
        assert image_size > 10000, f"画像サイズが小さすぎます ({image_size} bytes)。SVGA(800x600)のJPEGとしては異常です。"
        print(f"  ✅ 画像データを受信しました ({image_size} bytes)。")

        # 4. 画像をファイルに保存
        with open(output_filename, "wb") as f:
            f.write(response.content)
        print(f"  ✅ 画像を '{output_filename}' として保存しました。")

        # 5. 保存した画像の検証
        print("\n--- 画像内容の検証 ---")
        try:
            with Image.open(output_filename) as img:
                # 5a. 画像形式の検証
                print(f"  画像形式: {img.format}")
                assert img.format == 'JPEG', f"期待する画像形式は 'JPEG' ですが、実際は '{img.format}' でした。"
                print("  ✅ 画像形式はJPEGです。")

                # 5b. 解像度の検証
                print(f"  解像度: {img.size[0]}x{img.size[1]}")
                assert img.size == EXPECTED_RESOLUTION, f"期待する解像度は {EXPECTED_RESOLUTION} ですが、実際は {img.size} でした。"
                print(f"  ✅ 解像度が {EXPECTED_RESOLUTION} です。")

        except Exception as e:
            print(f"❌ 保存した画像の検証中にエラーが発生しました: {e}")
            raise AssertionError(f"画像の検証に失敗しました。ファイル '{output_filename}' を確認してください。")

        print("\n🎉 テストは成功しました！")
        return True

    except requests.exceptions.RequestException as e:
        print(f"❌ HTTPリクエスト中にエラーが発生しました: {e}")
        return False
    except AssertionError as e:
        print(f"❌ テストに失敗しました: {e}")
        return False
    except Exception as e:
        print(f"❌ 不明なエラーが発生しました: {e}")
        return False

if __name__ == "__main__":
    print("========================================")
    print(" ESP32-CAM キャプチャ機能 自動テスト")
    print("========================================")

    # ESP32-CAMをリセットするように促す
    input("ESP32-CAMの 'EN' または 'RST' ボタンを押してリセットし、準備ができたらEnterキーを押してください...")

    ip = get_ip_from_serial()

    if ip:
        if not test_capture(ip):
            exit(1) # テスト失敗で終了
    else:
        print("\nテストを実行できませんでした。")
        exit(1) # IP取得失敗で終了