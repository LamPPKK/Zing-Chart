import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';

test('registers Tizen media keys and normalizes the Play/Pause event', async () => {
  let keydownListener;
  let registeredKeys;
  let dispatchedEvent;
  const window = {
    tizen: {
      tvinputdevice: {
        getKey: (name) => ({ name }),
        registerKeyBatch: (keys) => { registeredKeys = keys; },
      },
    },
    addEventListener: (name, listener) => {
      if (name === 'keydown') keydownListener = listener;
    },
    dispatchEvent: (event) => { dispatchedEvent = event; },
  };
  class KeyboardEvent {
    constructor(type, init) {
      this.type = type;
      Object.assign(this, init);
    }
  }
  const context = {
    window,
    document: { readyState: 'complete' },
    KeyboardEvent,
    console: { warn: () => undefined },
  };
  const source = await readFile(
    path.resolve(import.meta.dirname, 'tv_remote.js'),
    'utf8',
  );
  vm.runInNewContext(source, context);

  assert.ok(registeredKeys.includes('MediaPlayPause'));
  const original = {
    keyCode: 10252,
    repeat: false,
    preventDefaultCalled: false,
    stopImmediatePropagationCalled: false,
    preventDefault() { this.preventDefaultCalled = true; },
    stopImmediatePropagation() { this.stopImmediatePropagationCalled = true; },
  };
  keydownListener(original);
  assert.equal(original.preventDefaultCalled, true);
  assert.equal(original.stopImmediatePropagationCalled, true);
  assert.equal(dispatchedEvent.key, 'MediaPlayPause');
  assert.equal(dispatchedEvent.code, 'MediaPlayPause');
});

test('normalizes Samsung and webOS Back buttons to Escape', async () => {
  let keydownListener;
  const dispatchedEvents = [];
  const window = {
    addEventListener: (name, listener) => {
      if (name === 'keydown') keydownListener = listener;
    },
    dispatchEvent: (event) => dispatchedEvents.push(event),
  };
  class KeyboardEvent {
    constructor(type, init) {
      this.type = type;
      Object.assign(this, init);
    }
  }
  const source = await readFile(
    path.resolve(import.meta.dirname, 'tv_remote.js'),
    'utf8',
  );
  vm.runInNewContext(source, {
    window,
    document: {
      readyState: 'complete',
      addEventListener: () => undefined,
    },
    KeyboardEvent,
    console: { warn: () => undefined },
  });

  for (const keyCode of [461, 10009]) {
    const event = {
      keyCode,
      repeat: false,
      preventDefault() {},
      stopImmediatePropagation() {},
    };
    keydownListener(event);
  }

  assert.deepEqual(dispatchedEvents.map((event) => event.key), [
    'Escape',
    'Escape',
  ]);
});

test('shows an HTML confirmation and exits through the Tizen API', async () => {
  let exited = 0;
  const listeners = new Map();
  const body = fakeElement('body');
  const window = {
    tizen: {
      application: {
        getCurrentApplication: () => ({ exit: () => exited++ }),
      },
    },
    addEventListener: (name, listener) => {
      const values = listeners.get(name) ?? [];
      values.push(listener);
      listeners.set(name, values);
    },
    removeEventListener: (name, listener) => {
      listeners.set(
        name,
        (listeners.get(name) ?? []).filter((value) => value !== listener),
      );
    },
    dispatchEvent: () => undefined,
    close: () => undefined,
  };
  const document = {
    readyState: 'complete',
    body,
    createElement: fakeElement,
  };
  class KeyboardEvent {
    constructor(type, init) {
      this.type = type;
      Object.assign(this, init);
    }
  }
  const source = await readFile(
    path.resolve(import.meta.dirname, 'tv_remote.js'),
    'utf8',
  );
  vm.runInNewContext(source, {
    window,
    document,
    KeyboardEvent,
    console: { warn: () => undefined },
  });

  assert.equal(window.zingChartRequestExit(), true);
  const buttons = descendants(body).filter((element) => element.tag === 'button');
  assert.deepEqual(buttons.map((button) => button.textContent), [
    'Có, thoát',
    'Ở lại',
  ]);
  assert.equal(buttons[1].focused, true);

  const keydownListener = listeners.get('keydown')[0];
  keydownListener(fakeRemoteEvent(37));
  assert.equal(buttons[0].focused, true);
  keydownListener(fakeRemoteEvent(13));
  assert.equal(exited, 1);
  assert.equal(body.children[0].removed, true);
});

function fakeRemoteEvent(keyCode) {
  return {
    keyCode,
    preventDefault() {
      this.prevented = true;
    },
    stopImmediatePropagation() {
      this.stopped = true;
    },
  };
}

function fakeElement(tag) {
  return {
    tag,
    style: {},
    children: [],
    listeners: new Map(),
    setAttribute(name, value) {
      this[name] = value;
    },
    appendChild(child) {
      this.children.push(child);
    },
    addEventListener(name, listener) {
      this.listeners.set(name, listener);
    },
    focus() {
      this.focused = true;
    },
    click() {
      this.listeners.get('click')?.();
    },
    remove() {
      this.removed = true;
    },
  };
}

function descendants(element) {
  return [element, ...element.children.flatMap(descendants)];
}
