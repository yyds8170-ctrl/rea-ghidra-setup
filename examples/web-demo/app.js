// web-analyze 示例脚本：点按钮发一次 JSON 请求、写一个 localStorage 键
document.getElementById('btn').addEventListener('click', async () => {
  try {
    const r = await fetch('./api.json');
    const j = await r.json();
    document.getElementById('out').textContent = JSON.stringify(j);
  } catch (e) {
    document.getElementById('out').textContent = 'err: ' + e;
  }
});
localStorage.setItem('rea_demo_flag', '1');
