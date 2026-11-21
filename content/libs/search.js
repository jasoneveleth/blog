// Client-side search for the archive page.
//
// Scoring is BM25 over a tokenized title+body index (titles weighted 3x).
// Typo tolerance comes from expanding each query term to matching vocabulary
// terms: exact, prefix (incremental typing), and Levenshtein distance <= 1.
// Everything runs in memory on every keystroke; with a few dozen posts this is
// well under a frame even on a phone.
(function () {
  "use strict";

  var DOCS = window.SEARCH_INDEX || [];
  var input = document.getElementById("search-input");
  var content = document.querySelector(".franklin-content");
  if (!input || !content || !DOCS.length) return;

  var K1 = 1.5;
  var B = 0.75;

  // ---- tokenizer ----------------------------------------------------------
  function tokenize(s) {
    var m = s.toLowerCase().match(/[a-z0-9]+/g);
    if (!m) return [];
    var out = [];
    for (var i = 0; i < m.length; i++) if (m[i].length >= 2) out.push(m[i]);
    return out;
  }

  // ---- index --------------------------------------------------------------
  var N = DOCS.length;
  var postings = new Map(); // term -> Map(docId -> term frequency)
  var docLen = new Array(N).fill(0);
  var docLower = new Array(N); // lowercased body, for snippet extraction

  for (var id = 0; id < N; id++) {
    var d = DOCS[id];
    var toks = tokenize(d.title + " " + d.title + " " + d.title + " " + d.content);
    docLen[id] = toks.length;
    var tf = new Map();
    for (var t = 0; t < toks.length; t++) tf.set(toks[t], (tf.get(toks[t]) || 0) + 1);
    tf.forEach(function (count, term) {
      var p = postings.get(term);
      if (!p) { p = new Map(); postings.set(term, p); }
      p.set(id, count);
    });
    docLower[id] = (d.content || "").toLowerCase();
  }

  var avgdl = docLen.reduce(function (a, b) { return a + b; }, 0) / Math.max(1, N);
  var vocab = Array.from(postings.keys());
  var idf = new Map();
  postings.forEach(function (p, term) {
    var df = p.size;
    idf.set(term, Math.log(1 + (N - df + 0.5) / (df + 0.5)));
  });

  // ---- typo tolerance -----------------------------------------------------
  // True when a is reachable from b in one edit: a substitution, an
  // insertion/deletion, or one adjacent transposition (restricted Damerau).
  function withinOne(a, b) {
    if (a === b) return true;
    var la = a.length, lb = b.length;
    if (Math.abs(la - lb) > 1) return false;
    if (la === lb) {
      var diff = 0, first = -1;
      for (var i = 0; i < la; i++) {
        if (a[i] !== b[i]) {
          if (++diff > 2) return false;
          if (first < 0) first = i;
        }
      }
      if (diff <= 1) return true;
      return diff === 2 && a[first] === b[first + 1] && a[first + 1] === b[first];
    }
    var s = la > lb ? a : b, shorter = la > lb ? b : a; // s is the longer
    var si = 0, ti = 0, skipped = 0;
    while (si < s.length && ti < shorter.length) {
      if (s[si] === shorter[ti]) { si++; ti++; }
      else if (++skipped > 1) return false;
      else si++;
    }
    return true;
  }

  // Expand a query term to vocabulary terms with a confidence weight.
  function candidates(qt) {
    var m = new Map();
    function bump(term, w) { if ((m.get(term) || 0) < w) m.set(term, w); }
    for (var i = 0; i < vocab.length; i++) {
      var term = vocab[i];
      if (term === qt) { bump(term, 1.0); continue; }
      if (qt.length >= 3 && term.length > qt.length && term.lastIndexOf(qt, 0) === 0) {
        bump(term, 0.9); // prefix: "gradie" -> "gradient"
        continue;
      }
      if (qt.length >= 4 && Math.abs(term.length - qt.length) <= 1 && withinOne(term, qt)) {
        bump(term, 0.6); // one typo
      }
    }
    return m;
  }

  // ---- DOM wiring ---------------------------------------------------------
  // Archive links may be relative ("2025/.../slug") or prefixed ("/blog/2025/…");
  // compare on the slug with leading/trailing slashes stripped.
  function slug(u) { return u.replace(/^\/+/, "").replace(/\/+$/, ""); }

  var byPath = new Map();
  for (var k = 0; k < N; k++) byPath.set(slug(DOCS[k].url), k);

  function resolveId(href) {
    var h = slug(href);
    if (byPath.has(h)) return byPath.get(h);
    for (var i = 0; i < N; i++) {
      var p = slug(DOCS[i].url);
      if (h === p || h.slice(-(p.length + 1)) === "/" + p) return i;
    }
    return -1;
  }

  var entries = []; // { el, id, snip }
  var managed = []; // headings + entry paragraphs, in document order
  var children = Array.prototype.slice.call(content.children);
  for (var c = 0; c < children.length; c++) {
    var el = children[c];
    if (el.tagName === "H2") { managed.push(el); continue; }
    if (el.tagName !== "P") continue;
    if (el.classList.contains("blog-description") || el.id === "search-empty") continue;
    var a = el.querySelector("a[href]");
    if (!a) continue;
    var snip = document.createElement("div");
    snip.className = "search-snippet";
    el.appendChild(snip);
    var e = { el: el, id: resolveId(a.getAttribute("href")), snip: snip };
    entries.push(e);
    managed.push(el);
  }

  var results = document.createElement("div");
  results.id = "search-results";
  results.hidden = true;
  if (managed.length) content.insertBefore(results, managed[0]);

  var emptyMsg = document.getElementById("search-empty");

  // ---- snippets -----------------------------------------------------------
  function escapeHtml(s) {
    return s.replace(/[&<>"]/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch];
    });
  }
  function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

  function makeSnippet(id, terms) {
    var lower = docLower[id];
    var body = DOCS[id].content || "";
    var pos = -1;
    terms.forEach(function (term) {
      var i = lower.indexOf(term);
      if (i >= 0 && (pos < 0 || i < pos)) pos = i;
    });
    if (pos < 0) pos = 0;
    var start = Math.max(0, pos - 60);
    while (start > 0 && /\w/.test(body[start - 1])) start--;
    var end = Math.min(body.length, start + 200);
    while (end < body.length && /\w/.test(body[end])) end++;
    var text = escapeHtml(body.slice(start, end).trim());
    if (terms.size) {
      var pat = Array.from(terms).sort(function (a, b) { return b.length - a.length; }).map(escapeRe).join("|");
      text = text.replace(new RegExp("\\b(" + pat + ")", "gi"), "<mark>$1</mark>");
    }
    return (start > 0 ? "… " : "") + text + (end < body.length ? " …" : "");
  }

  // ---- search -------------------------------------------------------------
  function score(q) {
    var scores = new Map();
    var matchedTerms = new Map();
    var perTerm = [];
    for (var i = 0; i < q.length; i++) {
      var hit = new Set();
      candidates(q[i]).forEach(function (w, term) {
        var weight = w, tIdf = idf.get(term);
        postings.get(term).forEach(function (tf, docId) {
          var dl = docLen[docId];
          var s = tIdf * (tf * (K1 + 1)) / (tf + K1 * (1 - B + B * dl / avgdl)) * weight;
          scores.set(docId, (scores.get(docId) || 0) + s);
          hit.add(docId);
          var mt = matchedTerms.get(docId);
          if (!mt) { mt = new Set(); matchedTerms.set(docId, mt); }
          mt.add(term);
        });
      });
      perTerm.push(hit);
    }
    var docs = Array.from(scores.keys());
    if (q.length > 1) {
      var andDocs = docs.filter(function (d) {
        return perTerm.every(function (set) { return set.has(d); });
      });
      if (andDocs.length) docs = andDocs;
    }
    docs.sort(function (a, b) { return scores.get(b) - scores.get(a); });
    return { docs: docs, scores: scores, terms: matchedTerms };
  }

  function reset() {
    for (var i = 0; i < managed.length; i++) {
      managed[i].hidden = false;
      content.insertBefore(managed[i], results);
    }
    for (var j = 0; j < entries.length; j++) closeSnippet(entries[j]);
    results.hidden = true;
    if (emptyMsg) emptyMsg.hidden = true;
  }

  function openSnippet(e, html) { e.snip.innerHTML = html; e.snip.classList.add("open"); }
  function closeSnippet(e) { e.snip.classList.remove("open"); e.snip.innerHTML = ""; }

  function run(raw) {
    var q = tokenize(raw);
    if (!q.length) { reset(); return; }

    var res = score(q);
    var keep = new Set(res.docs);

    for (var h = 0; h < managed.length; h++) {
      if (managed[h].tagName === "H2") managed[h].hidden = true;
    }

    var matched = [];
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i];
      if (e.id >= 0 && keep.has(e.id)) matched.push(e);
      else { e.el.hidden = true; closeSnippet(e); }
    }
    matched.sort(function (a, b) { return res.scores.get(b.id) - res.scores.get(a.id); });

    results.hidden = matched.length === 0;
    for (var m = 0; m < matched.length; m++) {
      var me = matched[m];
      me.el.hidden = false;
      openSnippet(me, makeSnippet(me.id, res.terms.get(me.id)));
      results.appendChild(me.el);
    }
    if (emptyMsg) emptyMsg.hidden = matched.length > 0;
  }

  var raf = 0;
  input.addEventListener("input", function () {
    if (raf) cancelAnimationFrame(raf);
    raf = requestAnimationFrame(function () { run(input.value); });
  });
})();
