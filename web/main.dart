// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:convert';

void main() {
  WebSocket ws = new WebSocket('ws://127.0.0.1:8888');
  
  ws.onOpen.listen((e) {
    print('Connected');
    ws.sendString(JSON.encode({'type': 'init'}));
  });
  
  // automatically decode all incoming messages
  ws.onMessage.map((MessageEvent e) => 
    JSON.decode(e.data)).listen((Map json) {
      String html = '<p><b>${json['name']}</b>: ${json['text']}</p>';
      querySelector('#chat').appendHtml(html);
  });
  
  querySelector('#name').onKeyUp.listen((e) {
    ws.sendString(JSON.encode({
      'type': 'change_name',
      'name': e.target.value
    }));
  });
  
  querySelector('#btn-send').onClick.listen((e) {
    InputElement input = querySelector('#msg');
    ws.sendString(JSON.encode({ 'type': 'post', 'text': input.value }));
    input.value = '';
  });
}

