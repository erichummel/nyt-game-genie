function typeAll(words) {
  for(i = 0; i < words.length; i++) {
    setTimeout(typeWord, i * 1000, words[i]);
  }
}

function typeWord(word) {
  for (i = 0; i < word.length; i++) {
    pressKey(word[i]);
  }
  pressKey('Enter');
}

function pressKey(char) {
  var keyboardEvent = new KeyboardEvent("keydown", {
    bubbles: true,
    cancelable: true,
    view: window,
    key: char,
  });
  document.dispatchEvent(keyboardEvent);
}
