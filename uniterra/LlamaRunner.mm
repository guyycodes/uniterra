//
//  LlamaRunner.mm
//  uniterra
//
//  Created by Guy Morgan Beals on 10/17/25.
//

#import "LlamaRunner.h"
#include "llama.h"
#include "ggml.h"
#include <vector>
#include <string>

@implementation LlamaRunner {
    llama_model *model;
    llama_context *ctx;
    llama_sampler *sampler;
}

- (instancetype)initWithModelPath:(NSString *)modelPath {
    self = [super init];
    if (self) {
        NSLog(@"🔥 Initializing llama with model: %@", modelPath);
        
        // Initialize llama backend
        llama_backend_init();
        
        // Model parameters
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = 999; // 🔥 Offload all layers to Metal!
        model_params.use_mmap = true;
        model_params.use_mlock = false;
        
        // Load model
        const char *model_path_c = [modelPath UTF8String];
        model = llama_model_load_from_file(model_path_c, model_params);
        
        if (!model) {
            NSLog(@"❌ Failed to load model from: %@", modelPath);
            return nil;
        }
        
        NSLog(@"✅ Model loaded successfully");
        
        // Context parameters
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 512; // Context size
        ctx_params.n_batch = 512;
        ctx_params.n_threads = 4;
        
        // Create context
        ctx = llama_init_from_model(model, ctx_params);
        
        if (!ctx) {
            NSLog(@"❌ Failed to create context");
            llama_model_free(model);
            return nil;
        }
        
        NSLog(@"✅ Context created successfully");
        
        // Create sampler
        auto sparams = llama_sampler_chain_default_params();
        sampler = llama_sampler_chain_init(sparams);
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7f));
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9f, 1));
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
        
        NSLog(@"✅ LlamaRunner initialized - Metal should be active!");
    }
    return self;
}

- (nullable NSString *)generateResponseForPrompt:(NSString *)prompt {
    if (!ctx || !model) {
        NSLog(@"❌ Context or model is null");
        return nil;
    }
    
    NSLog(@"🔥 Generating response for: %@", prompt);
    
    // Get vocab
    const struct llama_vocab * vocab = llama_model_get_vocab(model);
    
    // Tokenize prompt
    std::vector<llama_token> tokens_list;
    const char *prompt_c = [prompt UTF8String];
    
    tokens_list.resize(512);
    int n_tokens = llama_tokenize(
        vocab,
        prompt_c,
        strlen(prompt_c),
        tokens_list.data(),
        tokens_list.size(),
        true, // add_bos
        false // special
    );
    
    if (n_tokens < 0) {
        tokens_list.resize(-n_tokens);
        n_tokens = llama_tokenize(
            vocab,
            prompt_c,
            strlen(prompt_c),
            tokens_list.data(),
            tokens_list.size(),
            true,
            false
        );
    }
    
    tokens_list.resize(n_tokens);
    NSLog(@"📝 Tokenized input: %d tokens", n_tokens);
    
    // Create batch
    llama_batch batch = llama_batch_init(512, 0, 1);
    
    // Add tokens to batch manually
    for (size_t i = 0; i < tokens_list.size(); i++) {
        batch.token[i] = tokens_list[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = false;
    }
    batch.n_tokens = tokens_list.size();
    
    // Mark last token as needing logits
    if (batch.n_tokens > 0) {
        batch.logits[batch.n_tokens - 1] = true;
    }
    
    // Decode
    if (llama_decode(ctx, batch) != 0) {
        NSLog(@"❌ llama_decode failed");
        llama_batch_free(batch);
        return nil;
    }
    
    NSLog(@"✅ Initial decode successful");
    
    // Generate tokens
    NSMutableString *result = [NSMutableString string];
    int n_generated = 0;
    const int max_tokens = 100;
    
    while (n_generated < max_tokens) {
        llama_token new_token = llama_sampler_sample(sampler, ctx, -1);
        
        // Check for end of generation token
        if (new_token == llama_vocab_eos(vocab)) {
            NSLog(@"🏁 EOS token reached");
            break;
        }
        
        // Convert token to text
        char buf[256];
        int n = llama_token_to_piece(vocab, new_token, buf, sizeof(buf), 0, false);
        if (n > 0) {
            NSString *piece = [[NSString alloc] initWithBytes:buf length:n encoding:NSUTF8StringEncoding];
            if (piece) {
                [result appendString:piece];
            }
        }
        
        // Prepare batch for next token
        batch.n_tokens = 1;
        batch.token[0] = new_token;
        batch.pos[0] = tokens_list.size() + n_generated;
        batch.n_seq_id[0] = 1;
        batch.seq_id[0][0] = 0;
        batch.logits[0] = true;
        
        // Decode
        if (llama_decode(ctx, batch) != 0) {
            NSLog(@"❌ Decode failed at token %d", n_generated);
            break;
        }
        
        n_generated++;
    }
    
    llama_batch_free(batch);
    
    NSLog(@"✅ Generated %d tokens", n_generated);
    NSLog(@"📤 Response: %@", result);
    
    return [result copy];
}

- (void)cleanup {
    if (sampler) {
        llama_sampler_free(sampler);
        sampler = nil;
    }
    if (ctx) {
        llama_free(ctx);
        ctx = nil;
    }
    if (model) {
        llama_model_free(model);
        model = nil;
    }
    llama_backend_free();
}

- (void)dealloc {
    [self cleanup];
}

@end
