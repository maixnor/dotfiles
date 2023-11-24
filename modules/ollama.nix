{ pkgs, config, ... }:

let 
	ollamagpu = pkgs.ollama.override { llama-cpp = (pkgs.unstable.llama-cpp.override {cudaSupport = true; openblasSupport = false; }); };
in
{

    home.packages = with pkgs; [
				ollama
				nvidia-smi
    ];

}
