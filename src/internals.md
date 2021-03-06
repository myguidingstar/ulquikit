---
project_name: Ulquikit
authors: Duong H. Nguyen <cmpitg AT gmailDOTcom>
title: Ulquikit
short_description: Another literate programming tool in Racket
version: 0.0.1
---

# Ulquikit Internals #

This document describes how Ulquikit works and how it's used to bootstrap
itself.  For how to use Ulquikit in your project, see
[Ulquikit guide](guide.html).

## Concepts and definitions used in Ulquikit ##

Please see [Ulquikit guide](guide.html#concepts).

## How Ulquikit bootstraps itself ##

Ulquikit's project structure:

```
ulquikit/
  generated-docs/
  generated-src/
  src/
    bootstrap/
      css/
      js/
    config.yaml
    internals.md
    guide.md
```

Explanation:

| **Path**           | **Description**                                                             |
|--------------------|-----------------------------------------------------------------------------|
| `generated-docs/`  | *generated docs*                                                            |
| `generated-src/`   | *generated source*                                                          |
| `src/bootstrap/`   | resources for *generated docs* in HTML format                               |
| `src/config.yaml`  | Ulquikit configuration                                                      |
| `src/internals.md` | Literate source of this document, describing how Ulquikit works internally. |
| `src/guide.md`     | Literate source document, a guide on how to use Ulquikit                    |

## Notes ##

* All CSS and JavaScript files are minified with
  [Node Minify](https://github.com/srod/node-minify).

## License ##

Ulquikit is distributed under the terms of the GNU General Public License v3.
See [`COPYING`](COPYING) for further information.

---

* Write down something to test

  ```racket
  --> some-snippet-just-to-test <--
  #lang racket

  (define (hello-world)
    (displayln "¡Hola mundo!"))

  -{ some-comment-here }-

  (define (main)
    (hello-world))

  (main)
  ```

* And other stuff

  ```racket
  ___ ./main.rkt ___
  (begin)
    -{ some-snippet-just-to-test }-
  (end)
  ```

* And just some comment

  ```racket
  --> some-comment-here <--
  ;; Really
  ;; It's just some random comments
  ```
