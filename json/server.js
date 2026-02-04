const express = require('express');
const path   = require('path');
const app    = express();

const PORT = 3322;                     // 你想用的端口
const JSON_FILE = path.join(__dirname, '1.json'); // 放在同目录下

// 为了跨域访问（如果前端页面不在同一个域），可以加上 CORS 头
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
});

// 静态托管整个目录（如果还有其他资源想一起发布）
app.use(express.static(__dirname));

// 也可以单独写一个路由返回 JSON
app.get('/data.json', (req, res) => {
  res.sendFile(JSON_FILE);
});

app.listen(PORT, () => {
  console.log(`Server running at http://0.0.0.0:${PORT}`);
});
