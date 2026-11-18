// Fades the splash out once Flutter has painted its first frame.
window.addEventListener('flutter-first-frame', function () {
  var s = document.getElementById('splash');
  if (!s) return;
  s.classList.add('done');
  setTimeout(function () { s.remove(); }, 400);
});
