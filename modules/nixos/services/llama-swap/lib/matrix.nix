# Concurrency matrix, derived from each model's `placement`.
#
# One model per GPU may be resident, so the set is "any CUDA0 model & any CUDA1 model".
# A model with any other placement ("dual") appears in no set, which is what llama-swap
# reads as "runs alone and evicts everything".
#
# No `vars` table - llama-swap's DSL accepts model IDs directly. Identifiers may contain
# letters, digits, '_', '-' and '.' (internal/matrix/dsl.go isIdentChar), and an
# identifier that matches no var falls through to the model name
# (internal/config/matrix.go resolveMatrixModel). The hand-maintained alias table this
# replaces was the only part of the config that failed silently: a new model omitted from
# the set string simply never ran concurrently, with nothing to catch it.
{ lib }:
models:
let
  idsAt =
    placement: lib.attrNames (lib.filterAttrs (_: model: (model.placement or null) == placement) models);
  group = placement: "(" + lib.concatStringsSep " | " (idsAt placement) + ")";
in
{
  sets.concurrent = "${group "cuda0"} & ${group "cuda1"}";
}
