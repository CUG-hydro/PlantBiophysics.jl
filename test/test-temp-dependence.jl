# Importing the physical constants:
constants = Constants()

T = 28.0 - constants.K₀ # Current temperature
Tᵣ = 25.0 - constants.K₀ # Reference temperature
A = Fvcb(α=0.24) # because I set-up the tests with this value for α
@testset "Γ_star()" begin
    @test PlantBiophysics.Γ_star(T, Tᵣ, constants.R) ==
          PlantBiophysics.arrhenius(42.75, 37830.0, T, Tᵣ, constants.R)
end;

@testset "standard arrhenius()" begin
    @test PlantBiophysics.arrhenius(42.75, 37830.0, T, Tᵣ, constants.R) ≈ 49.76935360399572
end;

@testset "arrhenius() with negative effect of too high T" begin
    @test PlantBiophysics.arrhenius(A.JMaxRef, A.Eₐⱼ, T, Tᵣ, A.Hdⱼ, A.Δₛⱼ) ≈ 278.5161762418
    # NB: value checked using plantecophys.
end;

@testset "arrhenius() with negative effect of too high T" begin
    @test PlantBiophysics.arrhenius(A.JMaxRef, A.Eₐⱼ, T, Tᵣ, A.Hdⱼ, A.Δₛⱼ) ≈ 278.5161762418
    # NB: value checked using plantecophys.
end;

@testset "compare arrhenius() implementations" begin
    # arrhenius with negative effect of too high T should yield the same result as the standard Arrhenius
    # when Δₛ = 0.0
    @test PlantBiophysics.arrhenius(A.JMaxRef, A.Eₐⱼ, 28.0 - constants.K₀, A.Tᵣ - constants.K₀, A.Hdⱼ, 0.0) ==
          PlantBiophysics.arrhenius(A.JMaxRef, A.Eₐⱼ, 28.0 - constants.K₀, A.Tᵣ - constants.K₀)
end;
