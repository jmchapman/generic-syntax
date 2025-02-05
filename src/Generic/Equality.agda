{-# OPTIONS --with-K --safe --sized-types #-}

module Generic.Equality where

open import Size
open import Data.Unit
open import Data.Product
open import Data.List.Base using (List; []; _∷_)
open import Relation.Nullary
open import Relation.Binary.PropositionalEquality
open import Relation.Binary.PropositionalEquality.WithK

open import Data.Var
open import Generic.Syntax

private
  variable
    I : Set
    σ : I
    Γ : List I
    d : Desc I
    i : Size

Constraint : Desc I → Set
Constraint (`σ A d)   = ((a b : A) → Dec (a ≡ b))
                      × (∀ a → Constraint (d a))
Constraint (`X _ _ d) = Constraint d
Constraint (`∎ _)     = ⊤

eq^Var : (v w : Var σ Γ) → Dec (v ≡ w)
eq^Var z     z     = yes refl
eq^Var z     (s w) = no (λ ())
eq^Var (s v) z     = no (λ ())
eq^Var (s v) (s w) with eq^Var v w
... | yes p = yes (cong s p)
... | no ¬p = no λ where refl → ¬p refl

module _ (eq^d : Constraint d) where

  eq^Tm : (t u : Tm d i σ Γ) → Dec (t ≡ u)
  eq^⟦⟧ : ∀ e → Constraint e → (b c : ⟦ e ⟧ (Scope (Tm d i)) σ Γ) → Dec (b ≡ c)


  eq^Tm (`var v) (`con c) = no (λ ())
  eq^Tm (`con b) (`var w) = no (λ ())
  eq^Tm (`var v) (`var w) with eq^Var v w
  ... | yes p = yes (cong `var p)
  ... | no ¬p = no (λ where refl → ¬p refl)
  eq^Tm (`con b) (`con c) with eq^⟦⟧ _ eq^d b c
  ... | yes p = yes (cong `con p)
  ... | no ¬p = no (λ where refl → ¬p refl)

  eq^⟦⟧ (`σ A e) (eq^A , eq^e) (a₁ , b) (a₂ , c)
    with eq^A a₁ a₂
  ... | no ¬p = no (λ where refl → ¬p refl)
  ... | yes refl
    with eq^⟦⟧ (e a₁) (eq^e a₁) b c
  ... | yes q = yes (cong (_ ,_) q)
  ... | no ¬q = no (λ where refl → ¬q refl)
  eq^⟦⟧ (`X _ _ e) eq^e (t , b) (u , c)
    with eq^Tm t u | eq^⟦⟧ e eq^e b c
  ... | yes p | yes q = yes (cong₂ _,_ p q)
  ... | no ¬p | _     = no (λ where refl → ¬p refl)
  ... | _     | no ¬q = no (λ where refl → ¬q refl)
  eq^⟦⟧ (`∎ _) eq^e b c = yes (≡-irrelevant b c)
