using Test
using LogicCircuits
using ProbabilisticCircuits

include("helper/plain_logic_circuits.jl")

@testset "probabilistic circuit nodes" begin

    c1 = little_3var()

    @test isdisjoint(linearize(ProbCircuit(c1)), linearize(ProbCircuit(c1)))
    
    p1 = ProbCircuit(c1)
    lit3 = children(children(p1)[1])[1]

    # traits
    @test p1 isa ProbCircuit
    @test p1 isa PlainSumNode
    @test children(p1)[1] isa PlainMulNode
    @test lit3 isa PlainProbLiteralNode
    @test GateType(p1) isa ⋁Gate
    @test GateType(children(p1)[1]) isa ⋀Gate
    @test GateType(lit3) isa LiteralGate
    @test length(mul_nodes(p1)) == 4
    
    # methods
    @test num_parameters(p1) == 10

    # extension methods
    @test literal(lit3) === literal(children(children(c1)[1])[1])
    @test variable(left_most_descendent(p1)) == Var(3)
    @test ispositive(left_most_descendent(p1))
    @test !isnegative(left_most_descendent(p1))
    @test num_nodes(p1) == 15
    @test num_edges(p1) == 18

    r1 = fully_factorized_circuit(ProbCircuit,10)
    @test num_parameters(r1) == 2*10+1

    @test length(mul_nodes(r1)) == 1

    # compilation tests
    lit1 = compile(PlainProbCircuit, Lit(1))
    litn1 = compile(PlainProbCircuit, Lit(-1))
    r = lit1 * 0.3 + 0.7 * litn1
    @test r isa PlainSumNode
    @test all(children(r) .== [lit1, litn1])
    @test all(r.log_probs .≈ log.([0.3, 0.7]))
end