using Test
using LogicCircuits
using ProbabilisticCircuits
using DataFrames: DataFrame


@testset "structured probabilistic circuit nodes" begin

    vtree = PlainVtree(10, :balanced)
    f = fully_factorized_circuit(StructProbCircuit, vtree)
    @test f isa StructProbCircuit
    @test num_nodes(f) == 20+10+9*2+1
    @test num_edges(f) == 20+18+9+1
    @test length(mul_nodes(f)) == 9
    @test length(sum_nodes(f)) == 10+9+1
    @test num_parameters_node(f) == 1

    @test respects_vtree(f)
    @test respects_vtree(f, PlainVtree(10, :balanced))
    @test !respects_vtree(f, PlainVtree(5, :balanced))
    @test !respects_vtree(f, PlainVtree(10, :rightlinear))
    @test !respects_vtree(f, PlainVtree(10, :leftlinear))

    @test variable(left_most_descendent(f)) == Var(1)
    @test variable(right_most_descendent(f)) == Var(10)
    @test ispositive(left_most_descendent(f))
    @test isnegative(right_most_descendent(f))

    @test literal((StructProbCircuit,vtree)(Lit(-5))) == Lit(-5)

    @test_throws Exception multiply(StructProbCircuit[])
    @test_throws Exception summate(StructProbCircuit[])

    @test isdecomposable(f)

    @test variables(f) == BitSet(1:10)
    @test num_variables(f) == 10
    @test issmooth(f)

    input = DataFrame(BitArray([1 0 1 0 1 0 1 0 1 0;
                1 1 1 1 1 1 1 1 1 1;
                0 0 0 0 0 0 0 0 0 0;
                0 1 1 0 1 0 0 1 0 1]))
    @test satisfies(f,input) == BitVector([1,1,1,1])

    plainf = PlainLogicCircuit(f) 
    foreach(plainf) do n
        @test n isa PlainLogicCircuit
    end
    @test plainf !== f
    @test num_edges(plainf) == num_edges(f)
    @test num_nodes(plainf) == num_nodes(f)
    @test length(and_nodes(plainf)) == 9
    @test length(or_nodes(plainf)) == 10+9+1
    @test model_count(plainf) == BigInt(2)^10
    @test isempty(intersect(linearize(f),linearize(plainf)))

    ref = StructProbCircuit(vtree,plainf)
    foreach(ref) do n
        @test n isa StructProbCircuit
    end
    @test plainf !== ref
    @test f !== ref
    @test f.vtree === ref.vtree
    @test num_edges(ref) == num_edges(f)
    @test num_nodes(ref) == num_nodes(f)
    @test num_parameters_node(ref) == num_parameters_node(f)
    @test length(and_nodes(ref)) == 9
    @test length(or_nodes(ref)) == 10+9+1
    @test model_count(ref) == BigInt(2)^10
    @test isempty(intersect(linearize(f),linearize(ref)))

    ref = StructProbCircuit(vtree,f)
    foreach(ref) do n
        @test n isa StructProbCircuit
    end
    @test plainf !== ref
    @test f !== ref
    @test f.vtree === ref.vtree
    @test num_edges(ref) == num_edges(f)
    @test num_nodes(ref) == num_nodes(f)
    @test num_parameters_node(ref) == num_parameters_node(f)
    @test length(and_nodes(ref)) == 9
    @test length(or_nodes(ref)) == 10+9+1
    @test model_count(ref) == BigInt(2)^10
    @test isempty(intersect(linearize(f),linearize(ref)))

    mgr = SddMgr(7, :balanced)
    v = Dict([(i => compile(mgr, Lit(i))) for i=1:7])
    c = (v[1] | !v[2] | v[3]) &
        (v[2] | !v[7] | v[6]) &
        (v[3] | !v[4] | v[5]) &
        (v[1] | !v[4] | v[6])

    c2 = StructLogicCircuit(mgr, c)
    c2 = propagate_constants(c2; remove_unary=true)
    
    c3 = StructProbCircuit(mgr, c2)
    foreach(c3) do n
      @test n isa StructProbCircuit
    end
    @test num_edges(c3) == 69
    @test num_variables(c3) == 7

    # compilation tests
    v = Vtree(Var(1))
    @test_throws Exception compile(StructProbCircuit, v, true)
    lit1 = compile(StructProbCircuit, v, Lit(1))
    litn1 = compile(StructProbCircuit, v, Lit(-1))
    r = lit1 * 0.3 + 0.7 * litn1
    @test r isa StructSumNode
    @test all(children(r) .== [lit1, litn1])
    @test r.vtree === lit1.vtree
    @test all(r.log_probs .≈ log.([0.3, 0.7]))
    r1 = compile(r, r)
    @test r1 !== r
    @test r1.vtree === r.vtree
    @test num_edges(r1) == num_edges(r)
    @test num_nodes(r1) == num_nodes(r)
    @test num_parameters_node(r1) == num_parameters_node(r)
    @test isempty(intersect(linearize(r1),linearize(r)))

    # Convert tests
    function apply_test_cnf(n_vars::Int, cnf_path::String)
        for i in 1:10
            vtree = Vtree(n_vars, :random)
            sdd = compile(SddMgr(vtree), zoo_cnf(cnf_path))
            @test num_variables(sdd) == n_vars
            psdd = compile(StructProbCircuit, sdd)
            @test num_variables(psdd) == n_vars
            @test issmooth(psdd)
            @test isdecomposable(psdd)
            @test isdeterministic(psdd)
            @test respects_vtree(psdd, vtree)
            data = DataFrame(convert(BitMatrix, rand(Bool, 100, n_vars)))
            @test all(sdd(data) .== (EVI(psdd, data) .!=  -Inf))
        end
        nothing
    end
    apply_test_cnf(17, "easy/C17_mince.cnf")
    apply_test_cnf(14, "easy/majority_mince.cnf")
    apply_test_cnf(21, "easy/b1_mince.cnf")
    apply_test_cnf(20, "easy/cm152a_mince.cnf")
end

