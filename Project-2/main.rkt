; yusuf aygun
; 2020400033
; compiling: yes
; complete: yes

#lang racket

(provide (all-defined-out))

(define (binary_to_decimal binary)
  (string->number binary 2))

(define (relocator args limit base)
  (map (lambda (addr)
         (let ([decimal (binary_to_decimal addr)])
           (if (> decimal limit)
               -1
               (+ decimal base))))
       args))

(define (divide_address_space num page_size)
  (let* ([decimal-num (binary_to_decimal num)]
         [page-size-in-bits (* page_size 1024)]
         [page-num-decimal (quotient decimal-num page-size-in-bits)]
         [page-num-binary (number->string page-num-decimal 2)]
         [offset-decimal (- decimal-num (* page-num-decimal page-size-in-bits))]
         [offset-binary (number->string offset-decimal 2)]
         [offset-length (exact-ceiling (/ (log page-size-in-bits) (log 2)))]
         [padded-offset (let ([str offset-binary]
                              [length offset-length]
                              [pad-char #\0])
                          (if (< (string-length str) length)
                              (string-append (make-string (- length (string-length str)) pad-char) str)
                              str))])
    (list page-num-binary padded-offset)))

(define (page args page-table page-size)
  (let* ([n (string-length (number->string (sub1 (length page-table)) 2))])
    (map (lambda (addr)
           (let* ([page-number (substring addr 0 n)]
                  [page-offset (substring addr n)]
                  [m (string->number page-number 2)]
                  [new-page-number (list-ref page-table m)])
             (string-append new-page-number page-offset)))
         args)))

(define (find_sin value num)
  (define (factorial n)
    (if (<= n 1)
        1
        (* n (factorial (- n 1)))))
  
  (let* ([radians (degrees->radians value)]
         [terms (map (lambda (n)
                       (/ (* (expt -1 n) (expt radians (+ (* 2 n) 1)))
                          (factorial (+ (* 2 n) 1))))
                     (range 0 num))])
    (apply + terms)))

(define (myhash arg table-size)
  (let* ([decimal (binary_to_decimal arg)]
         [sin-value (find_sin decimal (+ (modulo decimal 5) 1))]
         [sin-string (number->string sin-value)]
         [dot-pos (regexp-match-positions #rx"[.]" sin-string)]
         [dot-index (if dot-pos (caar dot-pos) (string-length sin-string))]
         [start (+ dot-index 1)]
         [end (min (+ start 10) (string-length sin-string))]
         [sin-substring (substring sin-string start end)]
         [sin-digits (map (lambda (digit)
                            (string->number (string digit)))
                          (string->list sin-substring))]
         [sum (apply + sin-digits)])
    (modulo sum table-size)))

(define (hashed-page arg table-size page-table page-size)
  (let* ((arg-head (substring arg 0 page-size))
         (arg-tail (substring arg page-size))
         (index (myhash arg-head table-size))
         (entry (list-ref page-table index)))
    (let loop ((entry entry))
      (if (null? entry)
          arg
          (let* ((head (car (car entry)))
                 (tail (cadr (car entry))))
            (if (string=? head (substring arg-head 0 (string-length head)))
                (string-append tail (substring arg-head (string-length head)) arg-tail)
                (loop (cdr entry))))))))

(define (split_addresses args size)
  (let loop ([stream args]
             [result '()])
    (if (< (string-length stream) size)
        (reverse result)
        (loop (substring stream size) (cons (substring stream 0 size) result)))))

(define (map_addresses args table-size page-table page-size address-space-size)
  (let* ([addresses (split_addresses args address-space-size)]
         [physical-addresses (map (lambda (addr)
                                    (hashed-page addr table-size page-table page-size))
                                  addresses)])
    physical-addresses))
