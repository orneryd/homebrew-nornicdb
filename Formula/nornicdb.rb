require "securerandom"
require "yaml"

class Nornicdb < Formula
  desc "Graph, vector, and historical truth in one database"
  homepage "https://github.com/orneryd/NornicDB"
  url "https://github.com/orneryd/NornicDB/releases/download/v#{version}/nornicdb-darwin-arm64.tar.gz"
  version "1.1.7"
  sha256 "a254a0c5a1148df0fd4341d58a008c3a43e0ca3508b1e3218e4e678b64058b15"
  license "MIT"

  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/orneryd/NornicDB/releases/download/v#{version}/nornicdb-darwin-arm64.tar.gz"
      sha256 "a254a0c5a1148df0fd4341d58a008c3a43e0ca3508b1e3218e4e678b64058b15"
    end

    on_intel do
      url "https://github.com/orneryd/NornicDB/releases/download/v#{version}/nornicdb-darwin-amd64.tar.gz"
      sha256 "aeb20de2427dca75367d05633940335ce6540b3531f50b33ed0807b43bd9dcf8"
    end
  end

  def install
    bin.install "nornicdb"
  end

  def post_install
    (var/"nornicdb").mkpath
    (var/"nornicdb/models").mkpath
    (var/"log/nornicdb").mkpath
    (etc/"nornicdb").mkpath

    run_first_run_setup
  end

  service do
    run [opt_bin/"nornicdb", "serve", "--config", etc/"nornicdb/config.yaml"]
    keep_alive true
    working_dir var/"nornicdb"
    log_path var/"log/nornicdb/nornicdb.log"
    error_log_path var/"log/nornicdb/nornicdb.err.log"
    environment_variables NORNICDB_MODELS_DIR: (var/"nornicdb/models").to_s
  end

  def caveats
    <<~EOS
      NornicDB configuration:
        #{etc}/nornicdb/config.yaml

      Data directory:
        #{var}/nornicdb

      Local model directory:
        #{var}/nornicdb/models

      To rerun the Homebrew first-run setup:
        rm #{etc}/nornicdb/config.yaml
        brew postinstall nornicdb

      Start NornicDB as a service:
        brew services start nornicdb

      Open the web UI:
        http://localhost:7474
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/nornicdb version")
  end

  private

  def run_first_run_setup
    config_path = etc/"nornicdb/config.yaml"
    if config_path.exist?
      if interactive_install?
        return unless ask_yes_no("Existing NornicDB config found at #{config_path}. Reconfigure it?", false)
      else
        opoo "Existing NornicDB config found at #{config_path}; leaving it unchanged."
        return
      end
    end

    unless interactive_install?
      write_config(config_path, default_setup)
      opoo "Non-interactive install detected; wrote a Standard config with authentication disabled."
      opoo "Run `brew postinstall nornicdb` from an interactive terminal to reconfigure."
      return
    end

    ohai "NornicDB first-run setup"
    puts "This Homebrew setup mirrors the macOS first-run wizard and writes:"
    puts "  #{config_path}"
    puts

    setup = ask_setup
    write_config(config_path, setup)
    maybe_download_models(setup)

    ohai "NornicDB setup complete"
    puts "Config: #{config_path}"
    puts "Data:   #{var}/nornicdb"
    puts "Models: #{var}/nornicdb/models"
    puts
    puts "Start the service with:"
    puts "  brew services start nornicdb"
  end

  def interactive_install?
    $stdin.tty? && $stdout.tty?
  end

  def default_setup
    {
      profile:             "standard",
      auth_enabled:        false,
      admin_username:      "admin",
      admin_password:      "password",
      jwt_secret:          SecureRandom.urlsafe_base64(48),
      encryption_enabled:  false,
      encryption_password: nil,
    }
  end

  def ask_setup
    profile = ask_profile
    auth_enabled = ask_yes_no("Enable authentication?", true)
    admin_username = "admin"
    admin_password = "password"

    if auth_enabled
      admin_username = ask_text("Admin username", "admin")
      admin_password = ask_secret("Admin password (leave blank to generate)")
      if admin_password.empty?
        admin_password = SecureRandom.urlsafe_base64(24)
        puts "Generated admin password: #{admin_password}"
        puts "Store this password now; it will only be printed during setup."
      end
    end

    encryption_enabled = ask_yes_no("Enable database encryption at rest?", false)
    encryption_password = nil
    if encryption_enabled
      encryption_password = ask_secret("Encryption password (leave blank to generate)")
      if encryption_password.empty?
        encryption_password = SecureRandom.urlsafe_base64(32)
        puts "Generated encryption password: #{encryption_password}"
        puts "Store this password now; Homebrew writes it to the local config file."
      end
    end

    {
      profile:             profile,
      auth_enabled:        auth_enabled,
      admin_username:      admin_username,
      admin_password:      admin_password,
      jwt_secret:          SecureRandom.urlsafe_base64(48),
      encryption_enabled:  encryption_enabled,
      encryption_password: encryption_password,
    }
  end

  def ask_profile
    puts "Choose a setup profile:"
    puts "  1. Basic    - Neo4j compatibility, fast queries, low resource usage"
    puts "  2. Standard - Basic + vector embeddings, balanced local AI setup"
    puts "  3. Advanced - Standard + reranking, Heimdall, auto-predictions"

    loop do
      answer = ask_text("Profile [1-3]", "2")
      return "basic" if answer == "1" || answer.downcase == "basic"
      return "standard" if answer == "2" || answer.downcase == "standard"
      return "advanced" if answer == "3" || answer.downcase == "advanced"

      puts "Please choose 1, 2, or 3."
    end
  end

  def ask_text(prompt, default = nil)
    suffix = default.blank? ? ": " : " [#{default}]: "
    print "#{prompt}#{suffix}"
    answer = $stdin.gets&.strip.to_s
    (answer.empty? && default) ? default : answer
  end

  def ask_yes_no(prompt, default)
    default_text = default ? "Y/n" : "y/N"
    loop do
      answer = ask_text("#{prompt} #{default_text}", "")
      return default if answer.empty?
      return true if ["y", "yes"].include?(answer.downcase)
      return false if ["n", "no"].include?(answer.downcase)

      puts "Please answer yes or no."
    end
  end

  def ask_secret(prompt)
    print "#{prompt}: "
    if Kernel.system("stty", "-echo", out: File::NULL, err: File::NULL)
      begin
        answer = $stdin.gets&.strip.to_s
      ensure
        Kernel.system("stty", "echo", out: File::NULL, err: File::NULL)
        puts
      end
      answer
    else
      $stdin.gets&.strip.to_s
    end
  end

  def write_config(config_path, setup)
    config_path.dirname.mkpath
    File.write(config_path, nornicdb_config(setup))
    config_path.chmod(0600)
  end

  def nornicdb_config(setup)
    embeddings_enabled = setup[:profile] != "basic"
    advanced_enabled = setup[:profile] == "advanced"

    database = {
      "data_dir"               => (var/"nornicdb").to_s,
      "default_database"       => "nornic",
      "persist_search_indexes" => true,
    }
    if setup[:encryption_enabled]
      database["encryption_enabled"] = true
      database["encryption_password"] = setup[:encryption_password]
    end

    {
      "server"           => {
        "host"      => "127.0.0.1",
        "http_port" => 7474,
        "bolt_port" => 7687,
        "data_dir"  => (var/"nornicdb").to_s,
        "auth"      => setup[:auth_enabled] ? "#{setup[:admin_username]}:#{setup[:admin_password]}" : "none",
      },
      "auth"             => {
        "enabled"    => setup[:auth_enabled],
        "username"   => setup[:admin_username],
        "password"   => setup[:auth_enabled] ? setup[:admin_password] : "",
        "jwt_secret" => setup[:jwt_secret],
      },
      "database"         => database,
      "embedding"        => {
        "enabled"    => embeddings_enabled,
        "provider"   => "local",
        "model"      => "bge-m3.gguf",
        "dimensions" => 1024,
        "cache_size" => 10_000,
      },
      "embedding_worker" => {
        "chunk_size"    => 8192,
        "chunk_overlap" => 50,
      },
      "search"           => {
        "bm25_enabled"   => true,
        "bm25_warming"   => "startup",
        "vector_enabled" => true,
        "vector_warming" => "startup",
      },
      "memory"           => {
        "decay_enabled"                   => true,
        "auto_links_enabled"              => true,
        "auto_links_similarity_threshold" => 0.82,
        "query_cache_enabled"             => true,
        "query_cache_size"                => 1000,
        "query_cache_ttl"                 => "5m",
      },
      "search_rerank"    => {
        "enabled"  => advanced_enabled,
        "provider" => "local",
        "model"    => "bge-reranker-v2-m3-Q4_K_M.gguf",
      },
      "auto_tlp"         => {
        "enabled"   => advanced_enabled,
        "algorithm" => "adamic_adar",
        "weight"    => 0.25,
        "top_k"     => 5,
        "min_score" => 0.1,
      },
      "heimdall"         => {
        "enabled"           => advanced_enabled,
        "provider"          => "local",
        "model"             => "qwen3-0.6b-instruct.gguf",
        "gpu_layers"        => -1,
        "context_size"      => 8192,
        "batch_size"        => 2048,
        "max_tokens"        => 1024,
        "temperature"       => 0.5,
        "anomaly_detection" => advanced_enabled,
        "runtime_diagnosis" => advanced_enabled,
        "memory_curation"   => advanced_enabled,
      },
      "plugins"          => {
        "dir"          => (var/"nornicdb/plugins").to_s,
        "heimdall_dir" => (var/"nornicdb/plugins/heimdall").to_s,
      },
    }.to_yaml
  end

  def maybe_download_models(setup)
    models = required_models(setup[:profile])
    return if models.empty?

    puts
    puts "The #{setup[:profile]} profile uses local GGUF models in:"
    puts "  #{var}/nornicdb/models"
    puts
    models.each { |model| puts "  - #{model[:name]} (#{model[:file]})" }
    unless ask_yes_no("Download these models now?", true)
      puts "Skipped model downloads. Add the listed files to #{var}/nornicdb/models " \
           "before starting profiles that require local AI."
      return
    end

    (var/"nornicdb/models").mkpath
    models.each do |model|
      destination = var/"nornicdb/models"/model[:file]
      if destination.exist?
        puts "Already present: #{destination}"
        next
      end
      ohai "Downloading #{model[:name]}"
      system "curl", "-fL", "-o", destination.to_s, model[:url]
    end
  end

  def required_models(profile)
    return [] if profile == "basic"

    models = [
      {
        name: "BGE-M3 embeddings",
        file: "bge-m3.gguf",
        url:  "https://huggingface.co/gpustack/bge-m3-GGUF/resolve/main/bge-m3-Q4_K_M.gguf",
      },
    ]
    if profile == "advanced"
      models += [
        {
          name: "BGE reranker v2 m3",
          file: "bge-reranker-v2-m3-Q4_K_M.gguf",
          url:  "https://huggingface.co/gpustack/bge-reranker-v2-m3-GGUF/resolve/main/bge-reranker-v2-m3-Q4_K_M.gguf",
        },
        {
          name: "Qwen3 0.6B Heimdall",
          file: "qwen3-0.6b-instruct.gguf",
          url:  "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf",
        },
      ]
    end
    models
  end
end
