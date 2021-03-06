require "logger"

require "dotenv"
require "discordcr"

Dotenv.load!

# both of these get all entries added to them in their respective files

# things that require processing, i.e. katcase
COMMANDS = {} of String => (Discord::Message, Array(String)) -> Void
# just simple static image responses with optional text
MEMES = {} of String => {file: String, text: String?}

STORIES = {} of Discord::Snowflake => Discord::Snowflake

LOG    = Logger.new(STDOUT)
CLIENT = Discord::Client.new(
  token: "Bot #{ENV["DISCORD_TOKEN"]}",
  # suppress annoying library info logspam
  logger: Logger.new(STDOUT, level: Logger::Severity::WARN)
)
CACHE = Discord::Cache.new(CLIENT)
CLIENT.cache = CACHE

CLIENT.on_message_create do |msg|
  next if msg.author.bot

  if msg.content.starts_with?(",")
    word = msg.content.lchop(",").split(" ").first.downcase

    meme = MEMES[word]?
    if meme
      LOG.info("Sending '#{word}' for #{msg.author.id}")
      File.open("res/" + meme[:file]) do |file|
        CLIENT.upload_file(
          msg.channel_id,
          meme[:text] || "",
          file
        )
      end
      next
    end

    command = COMMANDS[word]?
    if command
      # chop off prefix and command word, split and remove empty strings
      args = msg.content[(word.size + 1)..].split(" ").reject!("")

      LOG.info("Running '#{word}'#{args} for #{msg.author.id}")
      command.call(msg, args)
    end
  else
    if mid = STORIES[msg.channel_id]?
      message = CLIENT.get_channel_message(msg.channel_id, mid)
      new_content = message.content.lchop("*Once upon a time…*") + " " + msg.content.split(" ")[0]
      if new_content.size < 2000
        CLIENT.delete_message(msg.channel_id, msg.id)
        CLIENT.edit_message(msg.channel_id, mid, new_content)
      else
        CLIENT.create_reaction(msg.channel_id, msg.id, URI.encode "❌")
      end
    end
  end
end

CLIENT.on_ready do |payload|
  CACHE.cache_current_user(payload.user)
end

require "./memes"
require "./commands"

LOG.info("Starting up...")
CLIENT.run
