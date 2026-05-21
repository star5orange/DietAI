"""
简单的测试 Agent，用于验证 LangGraph 服务和 Qwen (DashScope) 模型调用是否正常。

使用方式：
1. 在 langgraph.json 中注册后，通过 langgraph dev 启动
2. 发送消息测试模型是否能正常响应
"""

import os
from typing import TypedDict, Annotated

from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph, END


# ── State ──────────────────────────────────────────────────────────────
class TestState(TypedDict):
    """测试 Agent 的状态"""
    query: str          # 用户输入
    model_name: str     # 使用的模型名称
    response: str       # 模型响应内容
    status: str         # 执行状态: success / error


# ── Node ───────────────────────────────────────────────────────────────
def call_model(state: TestState) -> dict:
    """调用 Qwen 模型并返回响应"""
    query = state["query"]
    model_name = state.get("model_name")

    try:
        # DashScope 兼容 OpenAI 接口
        llm = ChatOpenAI(
            model=model_name,
            api_key=os.environ.get("DASHSCOPE_API_KEY"),
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
            temperature=0.7,
        )

        result = llm.invoke(query)

        return {
            "model_name": model_name,
            "response": result.content,
            "status": "success",
        }
    except Exception as e:
        return {
            "model_name": model_name,
            "response": f"调用失败: {e}",
            "status": "error",
        }


# ── Graph ──────────────────────────────────────────────────────────────
workflow = StateGraph(TestState)
workflow.add_node("call_model", call_model)
workflow.set_entry_point("call_model")
workflow.add_edge("call_model", END)

test_graph = workflow.compile()
