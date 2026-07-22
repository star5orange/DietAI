import asyncio
from langgraph_sdk import get_client

async def test():
    client = get_client(url="http://127.0.0.1:2024")
    assistant = await client.assistants.create(graph_id="chat_agent", config={"configurable": {}})
    thread = await client.threads.create()

    i = 0
    async for chunk in client.runs.stream(
        assistant_id=assistant["assistant_id"],
        thread_id=thread["thread_id"],
        input={"user_message": "推荐小暑节气的养生食谱，简短回答", "session_type": 5, "user_id": 10},
        stream_mode="values"
    ):
        i += 1
        d = chunk.data if hasattr(chunk, 'data') else None
        if isinstance(d, dict):
            print(f"[{i}] keys={list(d.keys())}")
            if "messages" in d:
                msgs = d["messages"]
                if msgs:
                    last = msgs[-1]
                    if hasattr(last, 'content'):
                        print(f"  messages[-1].content: {last.content[:100]}")
                    elif isinstance(last, dict):
                        print(f"  messages[-1]: {str(last)[:200]}")
            if "response_content" in d:
                print(f"  response_content: {d['response_content'][:100]}")
        elif d is not None:
            print(f"[{i}] data type={type(d).__name__}")

asyncio.run(test())
