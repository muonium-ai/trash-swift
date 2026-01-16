# Trash (Swift Port)

This repository is a modern Swift port of the original Objective‑C CLI app. The legacy implementation is preserved as a read‑only archive in [obj-c/](obj-c/).

## Purpose

`trash` is a small command-line program for macOS that moves files or folders to the trash.

## TODO (Porting Progress)

- [x] Decide target macOS + Swift versions.
- [x] Create SwiftPM package structure.
- [x] Port CLI parsing and help output.
- [x] Port stdout/stderr utilities + verbose logging.
- [x] Implement file existence checks (no leaf symlink follow).
- [x] Implement standard trashing (FileManager).
- [x] Implement Finder-based trashing ("put back" support).
- [x] Implement list/empty/secure empty flows.
- [x] Implement folder size aggregation and formatting.
- [ ] Add tests (unit + smoke).
- [ ] Update man page + release docs.

## Copyright

Original Objective‑C implementation:
- Copyright (c) 2010–2018 Ali Rantakari

Swift port:
- Copyright (c) 2026 Senthil Nayagam

See [my blog post][post] for more info on some initial implementation details and design decisions.

[post]: http://hasseg.org/blog/post/406/trash-files-from-the-os-x-command-line/


## Installing

Via [Homebrew]:

    brew install trash

Manually:

    $ make
    $ cp trash /usr/local/bin/
    $ make docs
    $ cp trash.1 /usr/local/share/man/man1/


[Homebrew]: http://brew.sh


## The “put back” feature

By default, `trash` uses the low-level system API to move the specified files/folders to the trash. If you want `trash` to ask Finder to perform the trashing (e.g. to ensure that the _"put back"_ feature works), supply the `-F` argument.



## The MIT License

Copyright (c) Ali Rantakari

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
