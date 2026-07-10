// Scroll parallax for layered stickers and reveal-on-scroll transitions.
// Effects only activate when the browser can run them; if JavaScript,
// IntersectionObserver, or the frame pipeline is unavailable, all content
// stays fully visible. Both effects respect prefers-reduced-motion.
(function () {
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Parallax: elements with data-speed drift as you scroll. The update is
  // cheap (a handful of transforms), so it runs directly in the scroll
  // handler with a small time-based throttle instead of relying on rAF.
  var floats = Array.prototype.slice.call(document.querySelectorAll('[data-speed]'));
  if (!reduceMotion && floats.length > 0) {
    var lastRun = 0;
    var update = function () {
      var y = window.scrollY;
      for (var i = 0; i < floats.length; i++) {
        var el = floats[i];
        var speed = parseFloat(el.getAttribute('data-speed')) || 0;
        if (el.getAttribute('data-mode') === 'margin') {
          // Blobs animate transform via CSS drift keyframes, so the scroll
          // offset rides on margin-top instead (SnapFridge.dc technique).
          el.style.marginTop = (y * speed).toFixed(1) + 'px';
        } else {
          el.style.transform =
            'translate3d(0, ' + (y * speed).toFixed(1) + 'px, 0) rotate(' + (el.getAttribute('data-rot') || '0') + 'deg)';
        }
      }
    };
    window.addEventListener(
      'scroll',
      function () {
        var now = Date.now();
        if (now - lastRun < 16) return;
        lastRun = now;
        update();
      },
      { passive: true }
    );
    update();
  }

  // Reveal: sections and cards fade and rise into place once. The hidden
  // initial state is only applied (via the html.fx class) after the observer
  // is confirmed working, and a safety timer reveals everything anyway.
  var revealables = Array.prototype.slice.call(document.querySelectorAll('.reveal'));
  if (reduceMotion || !('IntersectionObserver' in window) || revealables.length === 0) {
    return;
  }

  document.documentElement.classList.add('fx');

  var revealAll = function () {
    for (var i = 0; i < revealables.length; i++) revealables[i].classList.add('in');
  };

  // If the observer has not fired for anything shortly after setup (throttled
  // tab, embedded viewer, anything unexpected), show all content.
  var observerWorked = false;
  setTimeout(function () {
    if (!observerWorked) revealAll();
  }, 1200);

  var observer = new IntersectionObserver(
    function (entries) {
      observerWorked = true;
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12 }
  );
  revealables.forEach(function (el) { observer.observe(el); });
})();
