# Account-backed chat conversations

The AI chatbox stores conversations on the signed-in user's account. The chatbox uses one message view with a collapsible conversation sidebar. A persistent sidebar icon hides or shows the sidebar; it sits beside messages on desktop and overlays them on mobile. The list shows saved conversations; New chat creates an empty conversation, and each row has a delete button using the app's confirmation dialog. Titles come from the first message.

New conversations are limited to 30 per account per rolling hour, including conversations deleted during that hour. The legacy default-conversation path uses the same limit. On creation, up to 100 deleted empty conversations older than 30 days are removed; conversations containing message records remain for quota accounting. Sending the first message automatically creates a conversation when none is selected.

Sidebar responses merge by ID, preserve loaded pages and drafts, and exclude conversations deleted in the current browser view. Enter during Japanese/other IME composition does not send. Validation, quota, and generation failure messages support English, Vietnamese, and Japanese; generation jobs carry the request locale.

Conversation and message lists load lazily in pages of 20. The browser remembers the selected conversation ID as a convenience; messages and conversations are stored in PostgreSQL and remain available across devices. Older selections outside the first list page can be restored directly. Controls support English, Vietnamese, and Japanese, including mobile layouts.

All conversation lookups are scoped to the current account. Message creation validates the conversation owner and locks the conversation against concurrent deletion. AI memory and vector retrieval include only earlier messages from the current conversation. Switching conversations aborts stale history/status requests, and unsent drafts are preserved during navigation; reopening a conversation resumes polling its pending reply.

Deletion redacts message/response text, metadata, and vectors and marks the conversation deleted. Usage timestamps remain so deletion does not reset hourly or daily AI request limits. Deleted conversations cannot be read or written through the chat API. In-flight generation cannot restore cleared content.

Run `bundle exec rails db:migrate` before serving the new code, then restart web and worker processes when deploying. The migration moves existing messages into a conversation per account and derives its title from the first uncleared message. Existing messages are preserved.

Validation: the full Rails suite passed with 95 tests and 591 assertions before the final pagination addition. The final session integration/browser checks passed with 7 tests and 63 assertions, including pagination, ownership, mobile translations, switching, deletion, and navigation persistence. Chat polling JavaScript and Ruby lint checks pass. The local Docker app migration was verified with zero unassigned messages, and its workers were restarted.

## Blog retrieval and cards

Pure greetings and short social messages in English, Vietnamese, and Japanese skip blog retrieval and vector indexing. Other requests retrieve a bounded set of indexed published/verified posts, then discard vectors with cosine similarity below `AI_CHAT_MIN_POST_SIMILARITY` (default 0.35). This is a configurable heuristic that should be calibrated on actual content and embedding models; it is not a guarantee of semantic relevance. Explicit post context remains available for substantive questions opened from a post.

The assistant receives recent conversation context and qualifying posts. Blog cards are shown only for currently visible retrieved posts cited in the generated answer; there is no automatic fallback. Greetings therefore do not receive blog cards even if the answer invents a reference.
