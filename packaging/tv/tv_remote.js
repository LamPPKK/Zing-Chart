(function () {
  'use strict';

  var mediaKeys = [
    'MediaPlayPause',
    'MediaPlay',
    'MediaPause',
    'MediaStop',
    'MediaRewind',
    'MediaFastForward',
    'MediaTrackPrevious',
    'MediaTrackNext'
  ];
  var keyByCode = {
    19: 'MediaPause',
    412: 'MediaRewind',
    413: 'MediaStop',
    415: 'MediaPlay',
    461: 'Escape',
    417: 'MediaFastForward',
    10009: 'Escape',
    10232: 'MediaTrackPrevious',
    10233: 'MediaTrackNext',
    10252: 'MediaPlayPause'
  };
  var exitDialog = null;

  function closeExitDialog() {
    if (!exitDialog) return;
    exitDialog.overlay.remove();
    exitDialog = null;
  }

  function showExitDialog(exitApplication) {
    if (exitDialog) return;
    var overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-labelledby', 'zingchart-exit-title');
    overlay.style.cssText = [
      'position:fixed', 'inset:0', 'z-index:2147483647',
      'display:flex', 'align-items:center', 'justify-content:center',
      'background:rgba(8,9,10,.78)', 'font-family:sans-serif'
    ].join(';');

    var card = document.createElement('div');
    card.style.cssText = [
      'width:560px', 'max-width:80vw', 'padding:42px',
      'border:3px solid #b8f43d', 'border-radius:24px',
      'background:#17181b', 'color:#fff', 'text-align:center',
      'box-shadow:0 24px 80px rgba(0,0,0,.55)'
    ].join(';');
    var title = document.createElement('h1');
    title.id = 'zingchart-exit-title';
    title.textContent = 'Thoát #zingChart?';
    title.style.cssText = 'margin:0 0 16px;font-size:34px';
    var message = document.createElement('p');
    message.textContent = 'Nhạc đang phát sẽ dừng. Bạn có muốn thoát ứng dụng?';
    message.style.cssText = 'margin:0 0 32px;color:#d7d7d7;font-size:24px';
    var actions = document.createElement('div');
    actions.style.cssText = 'display:flex;gap:20px;justify-content:center';

    function makeButton(label) {
      var button = document.createElement('button');
      button.type = 'button';
      button.textContent = label;
      button.style.cssText = [
        'min-width:170px', 'padding:16px 24px',
        'border:3px solid transparent', 'border-radius:999px',
        'background:#292b30', 'color:#fff', 'font-size:24px',
        'font-weight:700'
      ].join(';');
      return button;
    }

    var yesButton = makeButton('Có, thoát');
    var noButton = makeButton('Ở lại');
    var buttons = [yesButton, noButton];
    var selectedIndex = 1;
    function select(index) {
      selectedIndex = index;
      buttons.forEach(function (button, buttonIndex) {
        var selected = buttonIndex === selectedIndex;
        button.style.borderColor = selected ? '#b8f43d' : 'transparent';
        button.style.background = selected ? '#ff6b4a' : '#292b30';
      });
      buttons[selectedIndex].focus();
    }
    yesButton.addEventListener('click', function () {
      closeExitDialog();
      exitApplication();
    });
    noButton.addEventListener('click', closeExitDialog);
    actions.appendChild(yesButton);
    actions.appendChild(noButton);
    card.appendChild(title);
    card.appendChild(message);
    card.appendChild(actions);
    overlay.appendChild(card);
    document.body.appendChild(overlay);

    function onKeyDown(event) {
      var code = event.keyCode || event.which;
      if (code === 37 || code === 39) {
        event.preventDefault();
        event.stopImmediatePropagation();
        select(selectedIndex === 0 ? 1 : 0);
      } else if (code === 13) {
        event.preventDefault();
        event.stopImmediatePropagation();
        buttons[selectedIndex].click();
      } else if (code === 27 || code === 461 || code === 10009) {
        event.preventDefault();
        event.stopImmediatePropagation();
        closeExitDialog();
      }
    }
    exitDialog = { overlay: overlay, onKeyDown: onKeyDown };
    select(selectedIndex);
  }

  window.zingChartRequestExit = function () {
    var tizenApplication = window.tizen && window.tizen.application;
    var isWebOs = Boolean(window.PalmSystem || window.webOSSystem);
    if (!tizenApplication && !isWebOs) return false;
    showExitDialog(function () {
      if (tizenApplication) {
        tizenApplication.getCurrentApplication().exit();
      } else {
        window.close();
      }
    });
    return true;
  };

  function registerTizenKeys() {
    if (!window.tizen || !window.tizen.tvinputdevice) return;
    try {
      var supported = mediaKeys.filter(function (name) {
        return window.tizen.tvinputdevice.getKey(name) !== null;
      });
      if (supported.length > 0) {
        window.tizen.tvinputdevice.registerKeyBatch(supported);
      }
    } catch (error) {
      console.warn('#zingChart could not register optional TV media keys.', error);
    }
  }

  // Samsung and LG remote media/Back buttons use numeric DOM key codes that
  // embedded Chromium versions do not consistently normalize. Re-dispatch
  // standard keys before Flutter installs its keyboard listener.
  window.addEventListener('keydown', function (event) {
    if (exitDialog) {
      exitDialog.onKeyDown(event);
      return;
    }
    var key = keyByCode[event.keyCode];
    if (!key) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    window.dispatchEvent(new KeyboardEvent('keydown', {
      key: key,
      code: key,
      bubbles: true,
      cancelable: true,
      repeat: event.repeat
    }));
  }, true);

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', registerTizenKeys, { once: true });
  } else {
    registerTizenKeys();
  }
}());
