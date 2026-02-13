# 🎅 SANTA: Scalable Accelerator for Nonlinear function with Tree-based Architecture

> **[2026 POLARIS Semiconductor Innovation Festival (SIF)](https://polargate.disu.ac.kr/contest/SIF2026/winner?sc=y)**
> Team-근사한사람들 (People of the Approximation)

## Introduction
SANTA는 Transformer 기반 언어 모델(BERT, GPT 등)의 핵심 병목 구간인 
Softmax Nonlinear function을 가속하기 위해 설계된 FPGA 기반의 Hardware Accelerator입니다.

현대의 AI 서비스는 음성 비서와 같은 짧은 쿼리(Short Query)부터 
LLM과 같은 긴 문맥(Long Context)까지 다양한 입력 길이를 처리해야 합니다. 
기존의 고정된 입력 크기(Fixed-size)를 가진 Accelerator들은 짧은 입력에 대해 불필요한 패딩 연산을 수행하거나, 
긴 입력에 대응하지 못하는 한계가 있었습니다.

**SANTA**는 **Tree-based Architecture**와 **Forwarding Logic**을 통해 이러한 문제를 해결합니다.
- Speed: 짧은 쿼리에 대해 연산을 병렬화하여 처리 속도를 극대화합니다.
- Scalability: Hardware의 물리적 크기 제약을 넘어, 최대 768 토큰의 긴 입력까지 유연하게 처리합니다.

## Key Features

### 1. Tree-Bypass Logic (Parallel Acceleration)
입력 길이에 따라 Hardware 리소스를 동적으로 재구성합니다.
- 가변 모드 지원: 입력 길이에 따라 `16x4`, `32x2`, `64x1` 모드로 동작합니다.
- 병렬 처리: 16 토큰 이하의 짧은 문장이 들어올 경우, 
4개의 Softmax 연산을 동시에 병렬 수행하여 처리량(Throughput)을 2.2배 향상시켰습니다 (SST-2 Validation Set).

### 2. Forwarding Logic (Infinite Scalability)
물리적인 버퍼 크기(64-input)를 초과하는 긴 문장도 처리할 수 있는 구조입니다.
- Local-to-Global Update: 데이터 묶음(Batch)마다 계산된 Local Max/Sum 값을 다음 연산으로 전달(Forwarding)하여 Global Softmax 값을 도출합니다.
- 유연성: 이를 통해 GPT/BERT의 최대 입력 길이인 768 토큰을 포함, 이론상 무제한의 길이를 처리할 수 있습니다.

### 3. Hardware-Efficient Approximation (RU)
복잡한 exponential 함수와 나눗셈 연산을 Hardware 친화적으로 최적화했습니다.
- Q6.10 Fixed-Point: 부동소수점 대신 고정소수점을 사용하여 연산 비용을 절감했습니다.
- Base-2 Transformation: 자연로그 대신 base-2 log와 exponential를 사용하여, 복잡한 연산을 단순 Shift와 Add로 대체했습니다.
- Resource Efficiency: FP16 모델 대비 LUT/FF 사용량 50% 절감, 전력 소모 27% 감소를 달성했으며 DSP 슬라이스를 전혀 사용하지 않습니다.

## System Architecture

The overall system operates via a Host-Accelerator hybrid flow:
1.  Host PC (Web UI): 사용자로부터 텍스트(GPT-2/BERT) 입력을 받습니다.
2.  Softmax HW API: PyTorch 모델의 Attention 레이어에서 Softmax 연산만 추출하여 UART로 전송합니다.
3.  SANTA Chip (FPGA):
    - UART Module: 데이터 수신 및 버퍼링.
    - Core: Max Tree -> Forwarding -> RU (Exp) -> Adder Tree -> Forwarding -> RU (Div).
4.  Output: 연산 결과를 Host로 반환하여 최종 텍스트 생성 또는 감정 분석 결과를 출력합니다.

| Component | Specification |
|:---:|:---|
| Board | Nexys A7-100T (Xilinx Artix-7) |
| Interface | UART (Universal Asynchronous Receiver-Transmitter) |
| Frequency | 100 MHz |
| Precision | Fixed-Point Q6.10 |

## Performance Evaluation

검증은 BERT-Base 모델과 SST-2 (Stanford Sentiment Treebank) 데이터셋을 사용하여 진행되었습니다.

| Metric | SW (PyTorch FP32) | HW (SANTA Q6.10) | Note |
|:---|:---:|:---:|:---|
| Accuracy | 92.4% | 92.2% | FP32 모델과 동등 수준의 정확도 유지 |
| Agreement | - | 99.8% | Float SW 모델과 결과값 99.8% 일치 |
| Throughput | 1.0x (Baseline) | 2.2x | 짧은 문장(Avg 25 tokens) 처리 시 가속 효과 |

## Demo
*실제 시연 환경에서는 Python FastAPI 기반의 Web 인터페이스를 통해 Hardware 동작을 시각화하였습니다.*

| Model | Input Example | Result |
|:---|:---|:---|
| Text Generation (GPT-2) | `Hi nice to` 입력 | `meet you.` 생성 (Hardware 가속) |
| Sentiment Analysis (BERT) | `I love you` 입력 | POSITIVE 판별 |

## Team-근사한사람들 (People of the Approximation)
- 박상혁 (Sanghyeok Park)
  - **Leader**
  - Idea Conception
  - System Architecture
  - RTL Design
  - Approximation Algorithm
  - FPGA Implementation
  - Verification
  - Software Integration
  - Host API Development
  - Figure Illustrations
- 김상윤 (Sang-yoon Kim)
  - RTL Design
  - UI/UX Design
  - Web API Development
  - Software Integration
  - Figure Illustrations
- 장서윤 (Seo-yoon Jang)
  - RTL Design
  - UI/UX Design
  - Figure Illustrations
  - Documentation

---
*This project was submitted to POLARIS SIF 2026.*