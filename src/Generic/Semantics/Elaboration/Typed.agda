{-# OPTIONS --safe --sized-types #-}
module Generic.Semantics.Elaboration.Typed where

import Level
open import Size
open import Function
import Category.Monad as CM
open import Data.Bool
open import Data.Product as Prod
open import Data.List hiding ([_] ; lookup)
open import Data.List.Relation.Unary.All as All hiding (lookup)
open import Data.Maybe as Maybe
open import Category.Monad
import Data.Maybe.Categorical as MC
open RawMonad (MC.monad {Level.zero})

open import Generic.Syntax.Bidirectional
open import Generic.Syntax.STLC as S

open import Relation.Unary hiding (_∈_)
open import Data.Var hiding (_<$>_)
open import Data.Environment hiding (_<$>_)
open import Generic.Syntax
open import Generic.Semantics

open import Relation.Binary.PropositionalEquality hiding ([_])


Typing : List Mode → Set
Typing = All (const Type)


private
  variable
    σ : Type
    m : Mode
    ms ns : List Mode

fromTyping : Typing ms → List Type
fromTyping []       = []
fromTyping (σ ∷ Γ)  = σ ∷ fromTyping Γ

Elab : Type ─Scoped → Type → (ms : List Mode) → Typing ms → Set
Elab T σ _ Γ = T σ (fromTyping Γ)

Elab- : Mode ─Scoped
Elab- Check  ms = ∀ Γ → (σ : Type) → Maybe (Elab (Tm STLC ∞) σ ms Γ)
Elab- Infer  ms = ∀ Γ → Maybe (Σ[ σ ∈ Type ] Elab (Tm STLC ∞) σ ms Γ)

data Var- : Mode ─Scoped where
  `var : (infer : ∀ Γ → Σ[ σ ∈ Type ] Elab Var σ ms Γ) → Var- Infer ms

open import Data.List.Relation.Unary.Any hiding (lookup)
open import Data.List.Membership.Propositional

toVar : m ∈ ms → Var m ms
toVar (here refl) = z
toVar (there v) = s (toVar v)

fromVar : Var m ms → m ∈ ms
fromVar z = here refl
fromVar (s v) = there (fromVar v)

coth^Typing : Typing ns → Thinning ms ns → Typing ms
coth^Typing Δ ρ = All.tabulate (λ x∈Γ → All.lookup Δ (fromVar (lookup ρ (toVar x∈Γ))))

lookup-fromVar : ∀ Δ (v : Var m ms) → Var (All.lookup Δ (fromVar v)) (fromTyping Δ)
lookup-fromVar (_ ∷ _) z     = z
lookup-fromVar (_ ∷ _) (s v) = s (lookup-fromVar _ v)

erase^coth : ∀ ms Δ (ρ : Thinning ms ns) →
             Var σ (fromTyping (coth^Typing Δ ρ)) → Var σ (fromTyping Δ)
erase^coth []       Δ ρ ()
erase^coth (m ∷ ms) Δ ρ z     = lookup-fromVar Δ (lookup ρ z)
erase^coth (m ∷ ms) Δ ρ (s v) = erase^coth ms Δ (select extend ρ) v

th^Var- : Thinnable (Var- m)
th^Var- (`var infer) ρ = `var λ Δ →
  let (σ , v) = infer (coth^Typing Δ ρ) in
  σ , erase^coth _ Δ ρ v

open Semantics

_=?_ : (σ τ : Type) → Maybe (σ ≡ τ)
α         =? α         = just refl
(σ `→ τ)  =? (φ `→ ψ)  = do
  refl ← σ =? φ
  refl ← τ =? ψ
  return refl
_ =? _ = nothing

data Arrow : Type → Set where
  _`→_ : ∀ σ τ → Arrow (σ `→ τ)

isArrow : ∀ σ → Maybe (Arrow σ)
isArrow (σ `→ τ)  = just (σ `→ τ)
isArrow _         = nothing

app : ∀[ Elab- Infer ⇒ Elab- Check ⇒ Elab- Infer ]
app f t Γ = do
  (arr , F)  ← f Γ
  (σ `→ τ)   ← isArrow arr
  T          ← t Γ σ
  return (τ , `app F T)

var₀ : Var- Infer (Infer ∷ ms)
var₀ = `var λ where (σ ∷ _) → (σ , z)

lam : ∀[ Kripke Var- Elab- (Infer ∷ []) Check ⇒ Elab- Check ]
lam b Γ arr = do
  (σ `→ τ)  ← isArrow arr
  B         ← b (bind Infer) (ε ∙ var₀) (σ ∷ Γ) τ
  return (`lam B)

emb : ∀[ Elab- Infer ⇒ Elab- Check ]
emb t Γ σ = do
  (τ , T)  ← t Γ
  refl     ← σ =? τ
  return T

cut : Type → ∀[ Elab- Check ⇒ Elab- Infer ]
cut σ t Γ = (σ ,_) <$> t Γ σ

Elaborate : Semantics Bidi Var- Elab-
Elaborate .th^𝓥  = th^Var-
Elaborate .var   = λ where (`var infer) Γ → just (map₂ `var (infer Γ))
Elaborate .alg   = λ where
  (PATTERNS.`app' f t)  → app f t
  (PATTERNS.`lam' b)    → lam b
  (PATTERNS.`emb' t)    → emb t
  (PATTERNS.`cut' σ t)  → cut σ t

Type- : Mode → Set
Type- Check  = ∀ σ → Maybe (TM STLC σ)
Type- Infer  = Maybe (∃ λ σ → TM STLC σ)

type- : ∀ p → TM Bidi p → Type- p
type- Check  t = closed Elaborate t []
type- Infer  t = closed Elaborate t []

module B = PATTERNS

module _ where

  private
    β : Type
    β = α `→ α

  _ :  type- Infer  ( B.`app (B.`cut (β `→ β)  id^B)  id^B)
    ≡  just (β      , S.`app                   id^S   id^S)
  _ = refl
