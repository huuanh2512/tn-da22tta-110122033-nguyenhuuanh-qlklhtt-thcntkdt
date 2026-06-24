const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();

// Mảng chứa danh sách toàn bộ API để đẩy lên UI
const apiEndpoints = [];

router.get('/health', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'API is running',
        code: 'OK'
    });
});
apiEndpoints.push('GET /api/v1/health');

const routesPath = __dirname;
fs.readdirSync(routesPath).forEach((file) => {
  if (file !== 'index.js' && file.endsWith('.routes.js')) {
    const routePrefix = file.split('.')[0];
    const route = require(path.join(routesPath, file));
    router.use(`/${routePrefix}`, route);
    
    // Tự động nội soi vào từng route con để lấy method và path
    if (route.stack && Array.isArray(route.stack)) {
        route.stack.forEach(layer => {
            if (layer.route) {
                const pathName = layer.route.path;
                const methods = Object.keys(layer.route.methods).map(m => m.toUpperCase());
                methods.forEach(method => {
                    apiEndpoints.push(`${method} /api/v1/${routePrefix}${pathName}`);
                });
            }
        });
    }
    
    console.log(`[Router] Mapped /api/v1/${routePrefix} -> ${file}`);
  }
});

// ---------------------------------------------------------
// TÍNH NĂNG MỚI: API Xuất danh sách ra file Markdown (.md)
// ---------------------------------------------------------
router.get('/export', (req, res) => {
    let mdContent = '# 🚀 Danh sách API Endpoints - Hệ thống Booking\n\n';
    mdContent += `*Cập nhật lần cuối: ${new Date().toLocaleString('vi-VN')}*\n\n`;
    mdContent += '---\n\n';
    mdContent += '### Chi tiết API\n\n';

    apiEndpoints.forEach(ep => {
        const parts = ep.split(' ');
        const method = parts[0];
        const apiPath = parts.slice(1).join(' ');
        
        // Thêm icon cho đẹp tùy theo Method
        let icon = '🔹';
        if(method === 'GET') icon = '🟢';
        if(method === 'POST') icon = '🟡';
        if(method === 'PUT') icon = '🟠';
        if(method === 'DELETE') icon = '🔴';

        mdContent += `- ${icon} **${method}** \`${apiPath}\`\n`;
    });

    // Ép trình duyệt tải file xuống thay vì hiển thị
    res.setHeader('Content-disposition', 'attachment; filename=API-List-Export.md');
    res.setHeader('Content-type', 'text/markdown; charset=utf-8');
    res.send(mdContent);
});

// Giao diện web tracking tiến độ
router.get('/tracker', (req, res) => {
  const html = `
  <!DOCTYPE html>
  <html lang="en">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Dev API Tracker</title>
      <style>
          body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #1e1e1e; color: #d4d4d4; padding: 20px; max-width: 800px; margin: auto; }
          .header-container { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #333; padding-bottom: 10px; margin-bottom: 20px;}
          h2 { color: #569cd6; margin: 0; }
          .btn-download { background: #4ec9b0; color: #1e1e1e; text-decoration: none; padding: 8px 16px; border-radius: 4px; font-weight: bold; font-size: 14px; transition: 0.2s; }
          .btn-download:hover { background: #3da892; }
          ul { list-style: none; padding: 0; }
          li { display: flex; align-items: center; background: #252526; margin: 8px 0; padding: 12px; border-radius: 6px; border: 1px solid #333; transition: 0.2s; }
          li:hover { background: #2d2d30; border-color: #555; }
          .checked { opacity: 0.4; text-decoration: line-through; }
          input[type="checkbox"] { transform: scale(1.5); margin-right: 15px; cursor: pointer; accent-color: #4ec9b0;}
          .method { font-weight: bold; padding: 4px 8px; border-radius: 4px; margin-right: 10px; font-size: 12px; width: 50px; text-align: center; }
          .GET { background: #61affe; color: #000; }
          .POST { background: #49cc90; color: #000; }
          .PUT { background: #fca130; color: #000; }
          .DELETE { background: #f93e3e; color: #fff; }
          .path { font-family: monospace; font-size: 15px; color: #ce9178; }
          .stats { font-size: 15px; margin-bottom: 10px; color: #4ec9b0; font-weight: bold; }
          .progress-bar { width: 100%; background: #333; border-radius: 4px; height: 8px; margin-top: 10px; overflow: hidden;}
          .progress-fill { height: 100%; background: #4ec9b0; width: 0%; transition: 0.3s; }
      </style>
  </head>
  <body>
      <div class="header-container">
          <h2>API Progress Tracker</h2>
          <!-- Nút Download gọi thẳng vào API /export vừa tạo -->
          <a href="/api/v1/export" class="btn-download">📥 Tải file Markdown</a>
      </div>
      
      <div class="stats" id="stats">Loading...</div>
      <div class="progress-bar"><div class="progress-fill" id="progress"></div></div>
      <br>
      <ul id="api-list"></ul>

      <script>
          const endpoints = ${JSON.stringify(apiEndpoints)};
          const list = document.getElementById('api-list');
          const stats = document.getElementById('stats');
          const progress = document.getElementById('progress');
          let checkedCount = 0;

          function updateStats() {
              stats.innerText = 'Đã hoàn thành: ' + checkedCount + ' / ' + endpoints.length + ' APIs';
              const percent = endpoints.length === 0 ? 0 : (checkedCount / endpoints.length) * 100;
              progress.style.width = percent + '%';
          }

          endpoints.forEach(ep => {
              const id = btoa(ep); // Mã hóa Base64 tên API làm key lưu trữ
              const isChecked = localStorage.getItem(id) === 'true';
              if (isChecked) checkedCount++;

              const li = document.createElement('li');
              if (isChecked) li.classList.add('checked');

              const checkbox = document.createElement('input');
              checkbox.type = 'checkbox';
              checkbox.checked = isChecked;

              checkbox.addEventListener('change', (e) => {
                  localStorage.setItem(id, e.target.checked);
                  if (e.target.checked) {
                      li.classList.add('checked');
                      checkedCount++;
                  } else {
                      li.classList.remove('checked');
                      checkedCount--;
                  }
                  updateStats();
              });

              const parts = ep.split(' ');
              const method = parts[0];
              const path = parts.slice(1).join(' ');

              const methodSpan = document.createElement('span');
              methodSpan.className = 'method ' + method;
              methodSpan.innerText = method;

              const pathSpan = document.createElement('span');
              pathSpan.className = 'path';
              pathSpan.innerText = path;

              li.appendChild(checkbox);
              li.appendChild(methodSpan);
              li.appendChild(pathSpan);
              list.appendChild(li);
          });

          updateStats();
      </script>
  </body>
  </html>
  `;
  res.send(html);
});

module.exports = router;