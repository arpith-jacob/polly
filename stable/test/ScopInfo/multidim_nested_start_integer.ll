; RUN: opt %loadPolly -polly-scops -analyze < %s | FileCheck %s
target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; void foo(long n, long m, long o, double A[n][m][o]) {
;   for (long i = 0; i < n; i++)
;     for (long j = 0; j < m; j++)
;       for (long k = 0; k < o; k++)
;         A[i+3][j-4][k+7] = 1.0;
; }
;
; Access function:
;
;   {{{(56 + (8 * (-4 + (3 * %m)) * %o) + %A),+,(8 * %m * %o)}<%for.i>,+,
;      (8 * %o)}<%for.j>,+,8}<%for.k>
;
; The nested 'start' should be splitted into three parameters:
;   p1: {0,+,(8 * %o)}<%for.j>
;   p2: {0,+,(8 * %m * %o)}<%for.i>
;   p3: (8 * (-4 + (3 * %m)) * %o)
;

define void @foo(i64 %n, i64 %m, i64 %o, double* %A) {
entry:
  br label %for.i

for.i:
  %i = phi i64 [ 0, %entry ], [ %i.inc, %for.i.inc ]
  br label %for.j

for.j:
  %j = phi i64 [ 0, %for.i ], [ %j.inc, %for.j.inc ]
  br label %for.k

for.k:
  %k = phi i64 [ 0, %for.j ], [ %k.inc, %for.k.inc ]
  %offset0 = add nsw i64 %i, 3
  %subscript0 = mul i64 %offset0, %m
  %offset1 = add nsw i64 %j, -4
  %subscript1 = add i64 %offset1, %subscript0
  %subscript2 = mul i64 %subscript1, %o
  %offset2 = add nsw i64 %k, 7
  %subscript = add i64 %subscript2, %offset2
  %idx = getelementptr inbounds double* %A, i64 %subscript
  store double 1.0, double* %idx
  br label %for.k.inc

for.k.inc:
  %k.inc = add nsw i64 %k, 1
  %k.exitcond = icmp eq i64 %k.inc, %o
  br i1 %k.exitcond, label %for.j.inc, label %for.k

for.j.inc:
  %j.inc = add nsw i64 %j, 1
  %j.exitcond = icmp eq i64 %j.inc, %m
  br i1 %j.exitcond, label %for.i.inc, label %for.j

for.i.inc:
  %i.inc = add nsw i64 %i, 1
  %i.exitcond = icmp eq i64 %i.inc, %n
  br i1 %i.exitcond, label %end, label %for.i

end:
  ret void
}

; CHECK: p0: %o
; CHECK: p1: {0,+,(8 * %o)}<%for.j>
; CHECK: p2: {0,+,(8 * %m * %o)}<%for.i>
; CHECK: p3: (8 * (-4 + (3 * %m)) * %o)
; CHECK-NOT: p4

; CHECK: Domain
; CHECK:   [o, p_1, p_2, p_3] -> { Stmt_for_k[i0] : i0 >= 0 and i0 <= -1 + o };
; CHECK: Scattering
; CHECK:   [o, p_1, p_2, p_3] -> { Stmt_for_k[i0] -> scattering[0, i0, 0] };
; CHECK: MustWriteAccess
; CHECK:   [o, p_1, p_2, p_3] -> { Stmt_for_k[i0] -> MemRef_A[o0] : 8o0 = 56 + p_1 + p_2 + p_3 + 8i0 };
