using Test
using LogicCircuits
using ProbabilisticCircuits
using DataFrames: DataFrame
using CUDA: CUDA

@testset "MLE tests" begin
    
    # Binary dataset
    dfb = DataFrame(BitMatrix([true false; true true; false true]))
    r = fully_factorized_circuit(ProbCircuit,num_features(dfb))
    
    estimate_parameters(r,dfb; pseudocount=1.0)
    @test log_likelihood_avg(r,dfb) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=1.0)

    estimate_parameters(r,dfb; pseudocount=0.0)
    @test log_likelihood_avg(r,dfb) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=0.0)

    if CUDA.functional()
        # Binary dataset
        dfb_gpu = to_gpu(dfb)
        
        estimate_parameters(r, dfb_gpu; pseudocount=1.0)
        @test log_likelihood_avg(r,dfb_gpu) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=1.0)

        estimate_parameters(r, dfb_gpu; pseudocount=0.0)
        @test log_likelihood_avg(r,dfb_gpu) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=0.0)
    end

end

@testset "Weighted MLE tests" begin
    # Binary dataset
    dfb = DataFrame(BitMatrix([true false; true true; false true]))
    r = fully_factorized_circuit(ProbCircuit,num_features(dfb))
    
    # Weighted binary dataset
    weights = DataFrame(weight = [0.6, 0.6, 0.6])
    wdfb = hcat(dfb, weights)
    
    estimate_parameters(r,wdfb; pseudocount=1.0)
    @test log_likelihood_avg(r,dfb) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=1.0)
    @test log_likelihood_avg(r,dfb) ≈ log_likelihood_avg(r,wdfb)
    
    estimate_parameters(r,wdfb; pseudocount=0.0)
    @test log_likelihood_avg(r,dfb) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=0.0)
    @test log_likelihood_avg(r,dfb) ≈ log_likelihood_avg(r,wdfb)

    if CUDA.functional()

        # Binary dataset
        dfb_gpu = to_gpu(dfb)
        
        # Weighted binary dataset
        weights_gpu = to_gpu(weights)
        
        estimate_parameters(r, dfb_gpu, weights_gpu; pseudocount=1.0)
        @test log_likelihood_avg(r,dfb_gpu) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=1.0)
        @test log_likelihood_avg(r,dfb_gpu) ≈ log_likelihood_avg(r, dfb_gpu, weights_gpu)

        estimate_parameters(r, dfb_gpu, weights_gpu; pseudocount=0.0)
        @test log_likelihood_avg(r,dfb_gpu) ≈ LogicCircuits.Utils.fully_factorized_log_likelihood(dfb; pseudocount=0.0)
        @test log_likelihood_avg(r,dfb_gpu) ≈ log_likelihood_avg(r, dfb_gpu, weights_gpu)

    end
end

@testset "EM tests" begin
    data = DataFrame([true missing])
    vtree2 = PlainVtree(2, :balanced)
    pc = fully_factorized_circuit(StructProbCircuit, vtree2).children[1]
    uniform_parameters(pc)
    pc.children[1].prime.log_probs .= log.([0.3, 0.7])
    pc.children[1].sub.log_probs .= log.([0.4, 0.6])
    estimate_parameters_em(pc, data; pseudocount=0.0)
    @test all(pc.children[1].prime.log_probs .== log.([1.0, 0.0]))
    @test pc.children[1].sub.log_probs[1] .≈ log.([0.4, 0.6])[1] atol=1e-6

    dfb = DataFrame(BitMatrix([true false; true true; false true]))
    r = fully_factorized_circuit(ProbCircuit,num_features(dfb))
    uniform_parameters(r)
    estimate_parameters(r,dfb; pseudocount=1.0)
    paras1 = ParamBitCircuit(r, dfb).params
    uniform_parameters(r)
    estimate_parameters_em(r, dfb; pseudocount=1.0)
    paras2 = ParamBitCircuit(r, dfb).params
    @test all(paras1 .≈ paras2)
end

@testset "Weighted EM tests" begin
    data = DataFrame([true missing])
    weights = DataFrame(weight = [1.0])
    wdata = hcat(data, weights)
    
    vtree2 = PlainVtree(2, :balanced)
    pc = fully_factorized_circuit(StructProbCircuit, vtree2).children[1]
    uniform_parameters(pc)
    pc.children[1].prime.log_probs .= log.([0.3, 0.7])
    pc.children[1].sub.log_probs .= log.([0.4, 0.6])
    estimate_parameters_em(pc, wdata; pseudocount=0.0)
    @test all(pc.children[1].prime.log_probs .== log.([1.0, 0.0]))
    @test pc.children[1].sub.log_probs[1] .≈ log.([0.4, 0.6])[1] atol=1e-6

    dfb = DataFrame(BitMatrix([true false; true true; false true]))
    weights = DataFrame(weight = [0.6, 0.6, 0.6])
    wdfb = hcat(dfb, weights)
    r = fully_factorized_circuit(ProbCircuit,num_features(dfb))
    uniform_parameters(r)
    estimate_parameters(r,wdfb; pseudocount=1.0)
    paras1 = ParamBitCircuit(r, wdfb).params
    uniform_parameters(r)
    estimate_parameters_em(r, wdfb; pseudocount=1.0)
    paras2 = ParamBitCircuit(r, wdfb).params
    @test all(paras1 .≈ paras2)
end