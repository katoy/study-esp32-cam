// ESP32-CAM Web Interface JavaScript

// Enhanced error suppression for browser extensions (especially Weblio's content.js)
// Extensions often inject content scripts that throw DOM-related errors which
// flood the console. This comprehensive suppression handles multiple error patterns.

// Global error handler
window.addEventListener('error', function(event) {
    try {
        const filename = event.filename || '';
        const message = event.message || '';
        const stack = (event.error && event.error.stack) || '';

        // Check for extension-related patterns
        const isExtensionError =
            filename.includes('content.js') ||
            filename.includes('extension') ||
            filename.includes('chrome-extension://') ||
            filename.includes('moz-extension://') ||
            message.includes('WeblioExtensions') ||
            message.includes('startContainer') ||
            message.includes('catchWord') ||
            stack.includes('content.js') ||
            stack.includes('extension');

        if (isExtensionError) {
            console.warn('🔇 Suppressed extension error:', {
                filename: filename,
                message: message,
                line: event.lineno
            });
            event.preventDefault();
            event.stopPropagation();
            return true;
        }
    } catch (e) {
        // Fail silently if error handler itself has issues
    }
});

// Promise rejection handler
window.addEventListener('unhandledrejection', function(event) {
    try {
        const reason = String(event.reason || '');

        if (reason.includes('content.js') ||
            reason.includes('WeblioExtensions') ||
            reason.includes('startContainer') ||
            reason.includes('extension')) {
            console.warn('🔇 Suppressed extension promise rejection:', reason);
            event.preventDefault();
        }
    } catch (e) {
        // Fail silently
    }
});

// Override console.error temporarily for extension errors
const originalConsoleError = console.error;
console.error = function(...args) {
    const message = args.join(' ');

    // Check if this is likely an extension error
    if (message.includes('content.js') ||
        message.includes('WeblioExtensions') ||
        message.includes('startContainer') ||
        message.includes('catchWord')) {
        // Suppress extension errors, but log a summary
        console.warn('🔇 Extension error suppressed');
        return;
    }

    // Allow other errors through
    originalConsoleError.apply(console, args);
};

// Global state
let isLivePreview = false;
let previewStateBeforeModal = false;
let streamImg = null; // current <img> element for live stream

// Protect critical DOM elements from extension interference
function protectDOMFromExtensions() {
    // Add data attributes that some extensions respect to avoid interference
    const mainElements = ['preview', 'fileList', 'controls'];

    mainElements.forEach(id => {
        const element = document.getElementById(id);
        if (element) {
            element.setAttribute('data-no-extension', 'true');
            element.setAttribute('data-translate', 'no');
            element.setAttribute('translate', 'no');
        }
    });

    // Disable text selection on critical UI elements to prevent extension interference
    const style = document.createElement('style');
    style.textContent = `
        .controls, .sidebar, .preview-area {
            -webkit-user-select: none;
            -moz-user-select: none;
            -ms-user-select: none;
            user-select: none;
        }
        .preview-image {
            pointer-events: auto;
            -webkit-user-select: none;
            -moz-user-select: none;
            user-select: none;
        }
    `;
    document.head.appendChild(style);
}

// Initialize the interface
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 DOMContentLoaded fired - Initializing interface...');

    // Protect DOM from extensions first
    protectDOMFromExtensions();
    updateFileList();
    updateSDInfo();


    // Add event listeners for buttons
    const previewBtn = document.getElementById('previewBtn');
    const captureBtn = document.getElementById('captureBtn');
    const rebootBtn = document.getElementById('rebootBtn');

    console.log('📋 Button elements found:', {
        previewBtn: !!previewBtn,
        captureBtn: !!captureBtn
    });

    if (previewBtn) {
        previewBtn.addEventListener('click', togglePreview);
        console.log('✅ Preview button listener added');
    } else {
        console.error('❌ Preview button not found');
    }

    if (captureBtn) {
        captureBtn.addEventListener('click', function(event) {
            console.log('📸 Capture button clicked');
            event.preventDefault();
            capturePhoto();
        });
        console.log('✅ Capture button listener added');

        // テスト用: ボタンが正しく見つかったことを確認
        console.log('📸 Capture button found:', captureBtn.id, captureBtn.textContent);
    } else {
        console.error('❌ Capture button not found');
        // デバッグ: 利用可能なボタンを一覧表示
        const allButtons = document.querySelectorAll('button');
        console.log('Available buttons:', Array.from(allButtons).map(btn => ({id: btn.id, text: btn.textContent})));
    }

    if (rebootBtn) {
        rebootBtn.addEventListener('click', function(event) {
            console.log('🔄 Reboot button clicked');
            event.preventDefault();
            rebootDevice();
        });
        console.log('✅ Reboot button listener added');
    } else {
        console.warn('⚠️ Reboot button not found');
    }

    // ハードウェア情報ボタンのイベントリスナー
    const infoBtn = document.getElementById('infoBtn');
    if (infoBtn) {
        infoBtn.addEventListener('click', toggleInfoPanel);
        console.log('✅ Info button listener added');
    } else {
        console.error('❌ Info button not found');
    }

    setupInfoControls();

    // 初期状態でcaptureボタンを無効化
    disableCaptureButton('Start live preview first');

    // 初期接続テスト（軽量なエンドポイント使用）
    console.log('🔍 Testing ESP32 connection...');
    fetch('/app/stream', {
        method: 'HEAD',
        signal: AbortSignal.timeout(3000)
    })
    .then(response => {
        if (response.ok) {
            console.log('✅ ESP32 connection OK:', response.status);
        } else {
            console.warn('⚠️  ESP32 responded with status:', response.status);
        }
    })
    .catch(error => {
        console.warn('⚠️  ESP32 connection test failed:', error.message);
        console.warn('💡 ハードウェア情報取得時にタイムアウトが発生する可能性があります');
    });    // Handle window resize to adjust image sizes
    window.addEventListener('resize', function() {
        const previewImage = document.querySelector('.preview-image');
        if (previewImage) {
            adjustImageSize(previewImage);
        }
    });
});

// Capture button state management
function enableCaptureButton() {
    const captureBtn = document.getElementById('captureBtn');
    if (captureBtn) {
        captureBtn.disabled = false;
        captureBtn.style.opacity = '1';
        captureBtn.title = 'カメラで撮影';
        console.log('✅ Capture button enabled');
    }
}

function disableCaptureButton(reason = '') {
    const captureBtn = document.getElementById('captureBtn');
    if (captureBtn) {
        captureBtn.disabled = true;
        captureBtn.style.opacity = '0.5';
        captureBtn.title = reason ? `使用不可: ${reason}` : '使用不可: ライブプレビューを開始してください';
        console.log(`❌ Capture button disabled: ${reason}`);
    }
}

// Device reboot flow
async function rebootDevice() {
    const wasPreviewRunning = isLivePreview;
    if (wasPreviewRunning) {
        console.log('🛑 Stopping preview before reboot');
        stopPreview();
    }

    const proceed = confirm('ESP32-CAM を再起動します。よろしいですか？');
    if (!proceed) {
        if (wasPreviewRunning) {
            setTimeout(startPreview, 100);
        }
        return;
    }

    showMessage('🔄 ESP32-CAM を再起動します…\n再接続でき次第、このページを更新します。', 'success');

    // Fire-and-forget reboot request (device may drop before responding)
    try {
        const controller = new AbortController();
        const t = setTimeout(() => controller.abort(), 1500);
        await fetch('/app/reboot', { method: 'POST', signal: controller.signal });
        clearTimeout(t);
    } catch (e) {
        console.warn('Reboot request likely interrupted (expected):', e.message);
    }

    // Poll until device is back online, then hard-reload with cache-buster
    const online = await waitForDeviceOnline(30000);
    if (online) {
        window.location.replace('/?v=' + Date.now());
    } else {
        showMessage('⏰ 再接続に失敗しました。\n手動でページを再読み込みしてください。', 'error');
    }
}

async function waitForDeviceOnline(timeoutMs = 30000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        try {
            const controller = new AbortController();
            const t = setTimeout(() => controller.abort(), 1500);
            const resp = await fetch('/app/stream', { method: 'HEAD', cache: 'no-store', signal: controller.signal });
            clearTimeout(t);
            if (resp && resp.ok) return true;
        } catch (e) {
            // ignore
        }
        await new Promise(r => setTimeout(r, 1200));
    }
    return false;
}

// Preview control functions
function stopPreview() {
    console.log('⏹ stopPreview called');
    const previewArea = document.getElementById('preview');
    const previewBtn = document.getElementById('previewBtn');

    // 明示的にストリーム画像を破棄して接続を切る
    if (streamImg) {
        try {
            streamImg.src = '';
            streamImg.remove();
        } catch (e) {
            console.warn('Stream image cleanup error:', e);
        }
        streamImg = null;
    }

    if (previewArea) {
        previewArea.innerHTML = '<div class="preview-placeholder">📸 Select a file to preview</div>';
    }
    if (previewBtn) {
        previewBtn.textContent = '📹 Start Preview';
    }

    // ストリーミング停止時はcaptureボタンを無効化
    disableCaptureButton('Preview stopped');
    isLivePreview = false;
}

function startPreview() {
    console.log('▶️ startPreview called');
    const previewArea = document.getElementById('preview');
    const previewBtn = document.getElementById('previewBtn');

    if (!previewArea || !previewBtn) {
        console.error('❌ Preview elements not found');
        return;
    }

    // Start live preview
    console.log('Starting live preview stream...');

    const img = document.createElement('img');
    img.src = '/app/stream';
    img.alt = 'Live Preview';
    img.className = 'preview-image';
    streamImg = img; // 保存して stopPreview で確実にクローズ

    // Loading状態を表示
    previewArea.innerHTML = '<div class="preview-placeholder">📡 Connecting to stream...</div>';

    // 5秒後にタイムアウトチェック
    const timeoutId = setTimeout(() => {
        if (isLivePreview && (!img.naturalWidth || img.naturalWidth === 0)) {
            console.warn('⚠️ Stream timeout - no image data received');
            previewArea.innerHTML = '<div class="preview-placeholder">⏱️ Stream timeout<br>ESP32-CAM may be busy or offline</div>';
            previewBtn.textContent = '📹 Start Preview';
            isLivePreview = false;

            // タイムアウト時はcaptureボタンを無効化
            disableCaptureButton('Stream timeout');
        }
    }, 5000);

    // 成功時の処理
    img.onload = function() {
        clearTimeout(timeoutId);
        console.log('✅ Stream connected successfully');
        previewArea.innerHTML = '';
        previewArea.appendChild(img);
        adjustImageSize(img);

        // ストリーミング開始時にcaptureボタンを有効化
        enableCaptureButton();
    };

    // エラー処理
    img.onerror = function() {
        clearTimeout(timeoutId);
        console.error('❌ Stream connection failed');
        previewArea.innerHTML = '<div class="preview-placeholder">❌ Stream connection failed<br>Please check ESP32-CAM status</div>';
        previewBtn.textContent = '📹 Start Preview';
        isLivePreview = false;

        // ストリーミング失敗時はcaptureボタンを無効化
        disableCaptureButton('Stream connection failed');
        return;
    };

    previewBtn.textContent = '⏹ Stop Preview';
    isLivePreview = true;
}

// Toggle live preview
function togglePreview() {
    console.log('🎬 togglePreview called');
    if (isLivePreview) {
        stopPreview();
    } else {
        startPreview();
    }
}

// Capture photo
async function capturePhoto() {
    console.log('📸 capturePhoto function called');
    console.log('🔍 Current isLivePreview state:', isLivePreview);
    const wasPreviewRunning = isLivePreview;
    // WebServer がストリームでブロックされるのを避けるため、撮影前にプレビューを停止し、サーバに停止を通知
    if (wasPreviewRunning) {
        console.log('🛑 Stopping live preview before capture to free server');
        stopPreview();
        // サーバ側のストリームループを確実に停止
        try {
            const controller = new AbortController();
            const t = setTimeout(() => controller.abort(), 2000);
            await fetch('/app/stream/stop', { method: 'POST', signal: controller.signal });
            clearTimeout(t);
        } catch (e) {
            console.warn('⚠️ stream/stop request failed or timed out:', e.message);
        }
        // 少しだけ待ってサーバ側がループを抜けるのを促す
        await new Promise(r => setTimeout(r, 50));
    }

    const captureBtn = document.getElementById('captureBtn');
    if (!captureBtn) {
        console.error('❌ captureBtn element not found');
        showMessage('❌ キャプチャボタンが見つかりません', 'error');
        return;
    }

    console.log('� Capture button state:', {
        disabled: captureBtn.disabled,
        text: captureBtn.textContent,
        visible: captureBtn.style.display !== 'none'
    });

    // ボタンの無効状態はここではチェックしない（stopPreview() 内で無効化されるため）

    console.log('�📸 Starting photo capture...');
    const originalText = captureBtn.textContent;

    // ボタン状態を更新
    captureBtn.disabled = true;
    captureBtn.textContent = '📸 Capturing...';

    // プログレス表示
    showMessage('📸 写真を撮影中...', 'info');

    console.log('📡 Sending POST request to /capture');

    // 手動タイムアウト制御（15秒）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
        console.error('⏰ Capture request timeout after 15 seconds');
        controller.abort();
    }, 15000);

    fetch('/app/capture', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        signal: controller.signal
    })
    .then(response => {
        console.log('📡 Response received, status:', response.status);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return response.json();
    })
    .then(data => {
        clearTimeout(timeoutId);
        console.log('📸 Capture response:', data);
        if (data.success) {
            showMessage(`📸 画像キャプチャ成功！\nファイル名: ${data.filename}`, 'success');
            console.log('📁 Updating file list...');
            updateFileList();
            updateSDInfo();
        } else {
            console.error('📸 Capture failed:', data.error);
            showMessage(`❌ キャプチャに失敗しました\n${data.error}`, 'error');
        }
    })
    .catch(error => {
        clearTimeout(timeoutId);
        console.error('❌ Capture error:', error);

        let errorMessage = 'Unknown error';
        if (error.name === 'AbortError') {
            errorMessage = 'タイムアウト（15秒経過）';
        } else if (error.message.includes('Failed to fetch')) {
            errorMessage = 'ネットワークエラー（ESP32に接続できません）';
        } else {
            errorMessage = error.message;
        }

        showMessage(`❌ キャプチャに失敗しました\nエラー: ${errorMessage}`, 'error');
    })
    .finally(() => {
        clearTimeout(timeoutId);
        console.log('📸 Capture process completed, restoring button');
        captureBtn.disabled = false;
        captureBtn.textContent = originalText;

        // 強制的にボタン状態をリセット（念のため）
        setTimeout(() => {
            if (captureBtn.disabled || captureBtn.textContent.includes('Capturing')) {
                console.warn('🔧 Force resetting capture button state');
                captureBtn.disabled = false;
                captureBtn.textContent = '📸 Capture';
            }
        }, 1000);

        // もとの状態がライブプレビュー中であれば再開
        if (wasPreviewRunning) {
            console.log('▶️ Restarting live preview after capture');
            startPreview();
        }
    });
}

// Update SD card info
function updateSDInfo() {
    fetch('/app/sdinfo')
        .then(response => response.json())
        .then(data => {
            console.log('💾 SD card info:', data);

            // 容量を分かりやすく変換
            const formatBytes = (bytes) => {
                if (bytes === 0) return '0 B';
                const k = 1024;
                const sizes = ['B', 'KB', 'MB', 'GB'];
                const i = Math.floor(Math.log(bytes) / Math.log(k));
                const value = parseFloat((bytes / Math.pow(k, i)).toFixed(1));
                return value + ' ' + sizes[i];
            };

            // 表示要素を更新
            document.getElementById('sdTotal').textContent = formatBytes(data.totalBytes);
            document.getElementById('sdUsed').textContent = formatBytes(data.usedBytes);
            document.getElementById('fileCount').textContent = data.fileCount + ' files';

            // 使用率バーを更新
            const usagePercent = data.usagePercent;
            const progressBar = document.querySelector('.header-sd-row .usage-fill');
            if (progressBar) {
                progressBar.style.width = usagePercent + '%';
            }

            // 使用率に応じて色を変更
            if (progressBar) {
                if (usagePercent < 70) {
                    progressBar.style.background = '#238636'; // 緑
                } else if (usagePercent < 90) {
                    progressBar.style.background = '#f1e05a'; // 黄
                } else {
                    progressBar.style.background = '#da3633'; // 赤
                }
            }
        })
        .catch(error => {
            console.error('Error fetching SD info:', error);
            document.getElementById('sdTotal').textContent = 'Error';
            document.getElementById('sdUsed').textContent = 'Error';
            document.getElementById('fileCount').textContent = 'Error';
        });
}



// Update file list
function updateFileList() {
    fetch('/app/files')
        .then(response => response.json())
        .then(data => {
            const fileList = document.getElementById('fileList');
            if (!fileList) return;

            if (data.files && data.files.length > 0) {
                // ファイルリスト
                const filesHTML = data.files.map(file => `
                    <div class="file-row">
                        <a href="#" onclick="previewFile('${file.name}')" class="file-link">
                            ${file.name}
                        </a>
                        <button class="delete-btn" onclick="deleteFile('${file.name}')" title="削除">🗑️</button>
                    </div>
                `).join('');

                fileList.innerHTML = `<div class="file-list">${filesHTML}</div>`;
            } else {
                fileList.innerHTML = `
                    <div class="empty-state">
                        <h2>No Photos</h2>
                        <p>Capture your first photo to get started!</p>
                    </div>
                `;
            }
        })
        .catch(error => {
            console.error('Error fetching files:', error);
            showMessage('❌ ファイル一覧の取得に失敗しました', 'error');
        });
}

// Preview selected file
function previewFile(filename) {
    console.log('previewFile called with:', filename);
    const previewArea = document.getElementById('preview');
    const previewBtn = document.getElementById('previewBtn');

    // Stop live preview if running
    if (isLivePreview) {
        isLivePreview = false;
        previewBtn.textContent = '📹 Start Preview';
    }

    // Create image element with proper sizing
    const img = document.createElement('img');
    const imageUrl = `/app/photo?name=${encodeURIComponent(filename)}`;

    console.log('🖼️ Creating image element for:', filename);
    console.log('📡 Request URL:', imageUrl);

    // Show loading state with progress indicator
    previewArea.innerHTML = '<div class="preview-placeholder">📷 Loading image...<br><div class="loading-spinner"></div></div>';

    // Track loading progress
    let progressReported = false;
    const progressTimer = setInterval(() => {
        if (!img.complete && !progressReported) {
            console.log('⏳ Image still loading... (5s elapsed)');
            previewArea.innerHTML = '<div class="preview-placeholder">📷 Loading image... (5s)<br><div class="loading-spinner"></div></div>';
            progressReported = true;
        }
    }, 5000);

    // Set loading timeout (10 seconds)
    const loadingTimeout = setTimeout(() => {
        clearInterval(progressTimer);
        if (img && !img.complete) {
            console.error('⏰ Image loading timeout after 10s:', filename);
            console.log('Image state:', {
                complete: img.complete,
                naturalWidth: img.naturalWidth,
                naturalHeight: img.naturalHeight,
                src: img.src
            });
            previewArea.innerHTML = '<div class="preview-placeholder">⏱️ Loading timeout (10s)<br>Image may be too large or server is busy<br><button onclick="previewFile(\'' + filename + '\')">🔄 Retry</button></div>';
        }
    }, 10000);

    // Handle image load events
    img.onload = function() {
        clearTimeout(loadingTimeout);
        clearInterval(progressTimer);
        console.log('✅ Image loaded successfully:', filename);
        console.log('📊 Image details:', {
            size: this.naturalWidth + 'x' + this.naturalHeight,
            fileSize: 'unknown',
            loadTime: 'completed'
        });
        previewArea.innerHTML = '';
        previewArea.appendChild(img);
        adjustImageSize(img);
    };

    img.onerror = function(event) {
        clearTimeout(loadingTimeout);
        clearInterval(progressTimer);
        console.error('❌ Image load error for:', filename);
        console.error('Error details:', {
            type: event.type,
            target: event.target,
            src: this.src,
            complete: this.complete
        });
        previewArea.innerHTML = '<div class="preview-placeholder">❌ Failed to load image<br>' + filename + '<br><button onclick="previewFile(\'' + filename + '\')">🔄 Retry</button></div>';
    };

    // Set image source to start loading (after event handlers are set)
    img.src = imageUrl;
    img.alt = filename;
    img.className = 'preview-image';

    // Network connectivity check
    fetch('/app/files', { method: 'HEAD' })
        .then(() => console.log('🌐 Network connectivity: OK'))
        .catch(() => console.warn('🌐 Network connectivity: Issues detected'));

    // Additional timeout check for incomplete loading
    setTimeout(() => {
        if (img && img.src && !img.complete && img.naturalWidth === 0) {
            console.warn('⏳ Image still loading after 5s:', filename);
            // Add debug info to UI
            const debugInfo = `
                <div style="font-size: 12px; color: #666; margin-top: 10px;">
                    Debug Info:<br>
                    • File: ${filename}<br>
                    • URL: ${imageUrl}<br>
                    • Status: Loading (5s+)<br>
                    • Network: Check console
                </div>`;
            if (previewArea.innerHTML.includes('Loading image...')) {
                previewArea.innerHTML = previewArea.innerHTML.replace('</div>', debugInfo + '</div>');
            }
            previewArea.innerHTML = '<div class="preview-placeholder">📷 Still loading...<br>Large image detected<br><button onclick="showPreview(\'' + filename + '\')">Cancel</button></div>';
        }
    }, 5000);
}

// Adjust image size to fit container (maintain SVGA 4:3 aspect ratio)
function adjustImageSize(img) {
    if (!img) return;

    // Remove any conflicting inline styles
    img.style.width = '';
    img.style.height = '';
    img.style.maxWidth = '';
    img.style.maxHeight = '';

    // Ensure proper class for CSS styling
    if (!img.classList.contains('preview-image')) {
        img.classList.add('preview-image');
    }

    // Calculate optimal size while maintaining 4:3 aspect ratio
    const container = img.parentElement;
    if (container) {
        const containerRect = container.getBoundingClientRect();
        const availableWidth = containerRect.width - 32; // padding
        const availableHeight = containerRect.height - 32; // padding

        // Calculate maximum size while maintaining 4:3 ratio
        const maxWidthFromHeight = (availableHeight * 4) / 3;
        const maxHeightFromWidth = (availableWidth * 3) / 4;

        let targetWidth, targetHeight;

        if (maxWidthFromHeight <= availableWidth) {
            // Height is the limiting factor
            targetWidth = Math.min(800, maxWidthFromHeight);
            targetHeight = (targetWidth * 3) / 4;
        } else {
            // Width is the limiting factor
            targetWidth = Math.min(800, availableWidth);
            targetHeight = (targetWidth * 3) / 4;
        }

        // Apply calculated size as CSS custom properties for responsiveness
        img.style.setProperty('--target-width', `${targetWidth}px`);
        img.style.setProperty('--target-height', `${targetHeight}px`);
    }

    // Force layout recalculation
    img.offsetHeight;
}

// Format file size as pseudo-time
function formatFileTime(size) {
    const kb = Math.floor(size / 1024);
    if (kb < 100) return `${kb}KB`;
    const mb = (size / 1024 / 1024).toFixed(1);
    return `${mb}MB`;
}

// チェックボックス管理関数

// Utility function for file operations
function deleteFile(filename) {
    if (confirm(`Delete ${filename}?`)) {
        fetch(`/app/delete?name=${encodeURIComponent(filename)}`, {
            method: 'DELETE'
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                showMessage(`🗑️ ファイルを削除しました\n${filename}`, 'success');
                updateFileList();
                updateSDInfo();
                // Clear preview if deleted file was being previewed
                const previewArea = document.getElementById('preview');
                if (previewArea && previewArea.querySelector('img')?.alt === filename) {
                    previewArea.innerHTML = '<div class="preview-placeholder">📸 Select a file to preview</div>';
                }
            } else {
                showMessage(`❌ ファイル削除に失敗しました\n${data.error}`, 'error');
            }
        })
        .catch(error => {
            console.error('Error deleting file:', error);
            showMessage(`❌ ファイル削除に失敗しました\nネットワークエラー: ${error.message}`, 'error');
        });
    }
}





// ハードウェア情報モーダル関連
function toggleInfoPanel() {
    showHardwareInfoModal();
}

function showHardwareInfoModal() {
    // プレビュー状態を保存してから停止
    previewStateBeforeModal = isLivePreview;
    if (isLivePreview) {
        console.log('📹 Stopping preview for hardware info modal');
        stopPreview();
    }

    // モーダルHTML作成
    const modalHTML = `
        <div id="hardwareModal" style="
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 2000;
            backdrop-filter: blur(2px);
        ">
            <div style="
                background: #0d1117;
                border: 1px solid #30363d;
                border-radius: 12px;
                padding: 24px;
                max-width: 500px;
                width: 90%;
                max-height: 80vh;
                overflow-y: auto;
                box-shadow: 0 16px 32px rgba(0, 0, 0, 0.6);
            ">
                <div style="
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 20px;
                    border-bottom: 1px solid #30363d;
                    padding-bottom: 12px;
                ">
                    <h3 style="
                        color: #f0f6fc;
                        margin: 0;
                        font-size: 18px;
                        font-weight: 600;
                    ">🔧 ハードウェア情報</h3>
                    <button onclick="closeHardwareModal()" style="
                        background: transparent;
                        border: none;
                        color: #8b949e;
                        font-size: 20px;
                        cursor: pointer;
                        padding: 4px;
                        border-radius: 4px;
                        line-height: 1;
                    " onmouseover="this.style.color='#f0f6fc'" onmouseout="this.style.color='#8b949e'">✕</button>
                </div>
                <div id="modalHardwareInfo" style="
                    color: #e6edf3;
                    line-height: 1.3;
                ">
                    <div style="text-align: center; color: #8b949e;">情報を読み込み中...</div>
                </div>
                <div style="
                    display: flex;
                    justify-content: center;
                    margin-top: 20px;
                    padding-top: 12px;
                    border-top: 1px solid #30363d;
                ">
                    <button onclick="closeHardwareModal()" style="
                        background: #238636;
                        color: #f0f6fc;
                        border: none;
                        padding: 10px 24px;
                        border-radius: 6px;
                        font-size: 14px;
                        cursor: pointer;
                        transition: background 0.2s;
                        font-weight: 500;
                    " onmouseover="this.style.background='#2ea043'" onmouseout="this.style.background='#238636'">✅ 閉じる</button>
                </div>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalHTML);

    // 初期読み込み
    loadHardwareInfoToModal();

    // ESCキーで閉じる
    const escHandler = (e) => {
        if (e.key === 'Escape') {
            closeHardwareModal();
            document.removeEventListener('keydown', escHandler);
        }
    };
    document.addEventListener('keydown', escHandler);

    // モーダル外クリックで閉じる
    document.getElementById('hardwareModal').addEventListener('click', (e) => {
        if (e.target.id === 'hardwareModal') {
            closeHardwareModal();
        }
    });
}

function closeHardwareModal() {
    console.log('🔧 Closing hardware info modal');
    const modal = document.getElementById('hardwareModal');
    if (modal) {
        modal.remove();
    }

    // プレビュー状態を復元
    if (previewStateBeforeModal && !isLivePreview) {
        console.log('📹 Restoring preview state (was active before modal)');
        setTimeout(() => {
            startPreview();
        }, 100); // 少し遅延させてモーダル削除を完了させる
    } else if (previewStateBeforeModal) {
        console.log('📹 Preview was active before modal but is currently active');
    } else {
        console.log('📹 Preview was not active before modal, keeping current state');
    }
    previewStateBeforeModal = false;
}

function setupInfoControls() {
    // モーダル用のため、既存のパネル制御は不要
}

function loadHardwareInfoToModal() {
    console.log('🔍 Starting hardware info load for modal...');
    const hardwareInfo = document.getElementById('modalHardwareInfo');

    if (!hardwareInfo) {
        console.error('❌ modalHardwareInfo element not found');
        return;
    }

    hardwareInfo.innerHTML = '<div style="text-align: center; color: #8b949e;">情報を読み込み中...</div>';
    console.log('📡 Fetching /app/hardware for modal...');

    // タイムアウトを設定（20秒に延長）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
        console.warn('⏰ Hardware info request timeout after 20 seconds');
        controller.abort();
    }, 20000);

    fetch('/app/hardware', {
        signal: controller.signal,
        headers: {
            'Accept': 'application/json'
        }
    })
        .then(response => {
            console.log('📨 Response received:', response.status, response.statusText);
            console.log('📨 Response headers:', response.headers);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return response.text(); // まずtextとして取得
        })
        .then(text => {
            console.log('📨 Raw response text:', text);
            try {
                const data = JSON.parse(text);
                console.log('✅ Parsed JSON data:', data);
                return data;
            } catch (parseError) {
                console.error('❌ JSON parse error:', parseError);
                throw new Error('Invalid JSON response: ' + parseError.message);
            }
        })
        .then(data => {
            clearTimeout(timeoutId);
            console.log('✅ Hardware data received:', data);
            displayHardwareInfoInModal(data);
            showMessage('✅ ハードウェア情報を更新しました', 'success');
        })
        .catch(error => {
            clearTimeout(timeoutId);
            console.error('❌ Hardware info fetch error:', error);

            let errorMsg = '不明なエラー';
            let debugInfo = '';

            if (error.name === 'AbortError') {
                errorMsg = 'リクエストがタイムアウトしました（20秒）';
                debugInfo = 'ESP32が応答していない可能性があります。シリアルモニタを確認してください。';
            } else if (error.message.includes('Failed to fetch')) {
                errorMsg = 'ネットワーク接続エラー';
                debugInfo = 'ESP32-CAMへの接続に失敗しました。IPアドレスを確認してください。';
            } else if (error.message.includes('Invalid JSON')) {
                errorMsg = 'レスポンス形式エラー';
                debugInfo = 'ESP32からの応答が正しくありません。ファームウェアを確認してください。';
            } else if (error.message) {
                errorMsg = error.message;
            }

            console.error('🔍 Debug info:', debugInfo);

            const fullErrorMsg = debugInfo ? errorMsg + '<br><small style="color: #8b949e;">' + debugInfo + '</small>' : errorMsg;
            hardwareInfo.innerHTML = '<div style="color: #f85149; text-align: center; line-height: 1.4;">❌ 情報の取得に失敗しました<br>' + fullErrorMsg + '</div>';
            showMessage('❌ ハードウェア情報の取得に失敗しました\n' + errorMsg + (debugInfo ? '\n' + debugInfo : ''), 'error');
        });
}

// 下位互換性のため、古いloadHardwareInfo呼び出しをモーダル版にリダイレクト
function loadHardwareInfo() {
    loadHardwareInfoToModal();
}

function displayHardwareInfoInModal(data) {
    console.log('🎯 displayHardwareInfoInModal called with data:', data);
    const hardwareInfo = document.getElementById('modalHardwareInfo');

    if (!hardwareInfo) {
        console.error('❌ modalHardwareInfo element not found');
        return;
    }

    const infoItems = [
        { label: 'チップモデル', value: data.chipModel },
        { label: 'チップリビジョン', value: `v${data.chipRevision}` },
        { label: 'CPUコア数', value: `${data.cpuCores} cores` },
        { label: 'CPU周波数', value: `${data.cpuFreqMHz}MHz` },
        { label: 'フラッシュサイズ', value: `${data.flashSizeMB}MB` },
        { label: 'PSRAMサイズ', value: `${data.psramSizeKB}KB` },
        { label: 'MACアドレス', value: data.macAddress.toUpperCase() },
        { label: 'ボードタイプ', value: data.boardType },
        { label: 'カメラセンサー', value: data.cameraSensor },
        { label: '画像サイズ', value: data.frameSize },
        { label: 'JPEG品質', value: data.jpegQuality }
    ];

    let html = '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 4px 16px; font-size: 14px;">';
    infoItems.forEach(item => {
        html += `
            <div style="
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 4px 0;
                border-bottom: 1px solid #21262d;
                margin-bottom: 2px;
            ">
                <span style="
                    color: #8b949e;
                    font-weight: 500;
                    min-width: 100px;
                ">${item.label}:</span>
                <span style="
                    color: #f0f6fc;
                    font-family: monospace;
                    font-size: 13px;
                    text-align: right;
                ">${item.value}</span>
            </div>
        `;
    });
    html += '</div>';

    hardwareInfo.innerHTML = html;
}

// 下位互換性のため、元の関数も残しておく
function displayHardwareInfo(data) {
    displayHardwareInfoInModal(data);
}

// メッセージ表示関数（汎用）
function showMessage(message, type) {
    const messageDiv = document.createElement('div');
    messageDiv.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 16px 24px;
        border-radius: 8px;
        color: #f0f6fc;
        font-weight: 500;
        font-family: monospace;
        white-space: pre-line;
        z-index: 1001;
        max-width: 400px;
        ${type === 'success' ? 'background: #238636; border: 1px solid #2ea043;' : 'background: #da3633; border: 1px solid #f85149;'}
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    `;
    messageDiv.textContent = message;

    document.body.appendChild(messageDiv);

    setTimeout(() => {
        messageDiv.remove();
    }, 5000);
}