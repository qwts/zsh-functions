class ZshFunctions < Formula
  desc "Common zsh shell functions"
  homepage "https://github.com/qwts/zsh-functions"
  url "git@github.com:qwts/zsh-functions.git", tag: "v0.1.0"
  version "0.1.0"
  head "git@github.com:qwts/zsh-functions.git", branch: "main"

  uses_from_macos "zsh"

  def install
    (share/"zsh-functions").mkpath
    (share/"zsh-functions").install Dir["functions/*"]
  end

  def caveats
    <<~EOS
      Add the functions directory to your fpath in ~/.zshrc:
        fpath=("#{HOMEBREW_PREFIX}/share/zsh-functions" $fpath)
    EOS
  end

  test do
    Dir[share/"zsh-functions/*"].each do |f|
      system "zsh", "-n", f
    end
  end
end
