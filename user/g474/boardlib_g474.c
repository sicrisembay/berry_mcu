#include "boardlib.h"
#include "stm32g4xx_hal.h"
#include <math.h>
#include <string.h>

#define SINE_POINTS 32U
#define DAC_MAX_VALUE 4095U

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static DAC_HandleTypeDef dac1;
static DMA_HandleTypeDef dac_dma;
static TIM_HandleTypeDef tim6;
static uint16_t waveform[SINE_POINTS];

static void dac_init(void)
{
    GPIO_InitTypeDef gpio = {0};
    DAC_ChannelConfTypeDef channel = {0};

    __HAL_RCC_GPIOA_CLK_ENABLE();
    gpio.Pin = GPIO_PIN_4;
    gpio.Mode = GPIO_MODE_ANALOG;
    gpio.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(GPIOA, &gpio);

    dac1.Instance = DAC1;
    if (HAL_DAC_Init(&dac1) != HAL_OK) {
        return;
    }

    channel.DAC_Trigger = DAC_TRIGGER_SOFTWARE;
    channel.DAC_OutputBuffer = DAC_OUTPUTBUFFER_ENABLE;
    channel.DAC_ConnectOnChipPeripheral = DAC_CHIPCONNECT_DISABLE;
    channel.DAC_UserTrimming = DAC_TRIMMING_FACTORY;
    HAL_DAC_ConfigChannel(&dac1, &channel, DAC_CHANNEL_1);
    HAL_DAC_Start(&dac1, DAC_CHANNEL_1);
    HAL_DAC_SetValue(&dac1, DAC_CHANNEL_1, DAC_ALIGN_12B_R, 0U);
}

void board_init(void)
{
    dac_init();
}

static void calculate_sine(float amplitude)
{
    for (uint32_t index = 0; index < SINE_POINTS; ++index) {
        float value = sinf((float)(2.0 * M_PI * index / SINE_POINTS));
        waveform[index] = (uint16_t)(value * amplitude * 2047.0f + 2047.0f);
    }
}

static void calculate_rectangle(float amplitude)
{
    for (uint32_t index = 0; index < SINE_POINTS; ++index) {
        float value = index < SINE_POINTS / 2U ? amplitude : -amplitude;
        waveform[index] = (uint16_t)(value * 2047.0f + 2047.0f);
    }
}

static void calculate_triangle(float amplitude)
{
    for (uint32_t index = 0; index < SINE_POINTS; ++index) {
        float phase = (float)index / (float)(SINE_POINTS / 2U);
        float value = phase < 1.0f ? phase : 2.0f - phase;
        waveform[index] = (uint16_t)((value * 2.0f - 1.0f) * amplitude * 2047.0f + 2047.0f);
    }
}

static void stop_waveform(void)
{
    HAL_TIM_Base_Stop(&tim6);
    HAL_DAC_Stop_DMA(&dac1, DAC_CHANNEL_1);
}

static int play_wave(bvm *vm, void (*calculate)(float))
{
    int frequency = be_toint(vm, 1);
    float amplitude = (float)be_toreal(vm, 2);
    uint32_t timer_clock;
    uint32_t period;
    TIM_MasterConfigTypeDef master = {0};
    DAC_ChannelConfTypeDef channel = {0};

    if (frequency <= 0) {
        be_return_nil(vm);
    }
    if (amplitude < 0.0f) {
        amplitude = 0.0f;
    }
    if (amplitude > 1.0f) {
        amplitude = 1.0f;
    }

    stop_waveform();
    calculate(amplitude);

    timer_clock = HAL_RCC_GetPCLK1Freq();
    period = timer_clock / (SINE_POINTS * (uint32_t)frequency);
    if (period == 0U) {
        period = 1U;
    }
    if (period > 65536U) {
        period = 65536U;
    }

    tim6.Instance = TIM6;
    tim6.Init.Prescaler = 0U;
    tim6.Init.CounterMode = TIM_COUNTERMODE_UP;
    tim6.Init.Period = period - 1U;
    tim6.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
    if (HAL_TIM_Base_Init(&tim6) != HAL_OK) {
        be_return_nil(vm);
    }

    master.MasterOutputTrigger = TIM_TRGO_UPDATE;
    master.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
    if (HAL_TIMEx_MasterConfigSynchronization(&tim6, &master) != HAL_OK) {
        be_return_nil(vm);
    }

    channel.DAC_Trigger = DAC_TRIGGER_T6_TRGO;
    channel.DAC_OutputBuffer = DAC_OUTPUTBUFFER_DISABLE;
    channel.DAC_ConnectOnChipPeripheral = DAC_CHIPCONNECT_DISABLE;
    channel.DAC_UserTrimming = DAC_TRIMMING_FACTORY;
    if (HAL_DAC_ConfigChannel(&dac1, &channel, DAC_CHANNEL_1) != HAL_OK) {
        be_return_nil(vm);
    }

    if (HAL_DAC_Start_DMA(&dac1, DAC_CHANNEL_1, (uint32_t *)waveform, SINE_POINTS, DAC_ALIGN_12B_R) != HAL_OK) {
        be_return_nil(vm);
    }
    HAL_TIM_Base_Start(&tim6);
    be_return_nil(vm);
}

static int setled(bvm *vm)
{
    if (be_isbool(vm, 1)) {
        HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5,
                          be_tobool(vm, 1) ? GPIO_PIN_SET : GPIO_PIN_RESET);
    }
    be_return_nil(vm);
}

static int setdac(bvm *vm)
{
    int channel = be_toint(vm, 1);
    int value = be_toint(vm, 2);

    if (channel == 1 && value >= 0 && value <= (int)DAC_MAX_VALUE) {
        HAL_DAC_SetValue(&dac1, DAC_CHANNEL_1, DAC_ALIGN_12B_R, (uint32_t)value);
    }
    be_return_nil(vm);
}

static int l_play_sin(bvm *vm)
{
    return play_wave(vm, calculate_sine);
}

static int l_play_rect(bvm *vm)
{
    return play_wave(vm, calculate_rectangle);
}

static int l_play_tri(bvm *vm)
{
    return play_wave(vm, calculate_triangle);
}

static int l_play_stop(bvm *vm)
{
    stop_waveform();
    dac_init();
    be_return_nil(vm);
}

static int l_reboot(bvm *vm)
{
    be_writestring("software reboot...\n\n");
    HAL_Delay(10U);
    NVIC_SystemReset();
    be_return_nil(vm);
}

void HAL_DAC_MspInit(DAC_HandleTypeDef *hdac)
{
    if (hdac->Instance == DAC1) {
        __HAL_RCC_DAC1_CLK_ENABLE();
        __HAL_RCC_DMA1_CLK_ENABLE();

        dac_dma.Instance = DMA1_Channel1;
        dac_dma.Init.Request = DMA_REQUEST_DAC1_CHANNEL1;
        dac_dma.Init.Direction = DMA_MEMORY_TO_PERIPH;
        dac_dma.Init.PeriphInc = DMA_PINC_DISABLE;
        dac_dma.Init.MemInc = DMA_MINC_ENABLE;
        dac_dma.Init.PeriphDataAlignment = DMA_PDATAALIGN_HALFWORD;
        dac_dma.Init.MemDataAlignment = DMA_MDATAALIGN_HALFWORD;
        dac_dma.Init.Mode = DMA_CIRCULAR;
        dac_dma.Init.Priority = DMA_PRIORITY_HIGH;
        HAL_DMA_Init(&dac_dma);
        __HAL_LINKDMA(hdac, DMA_Handle1, dac_dma);
    }
}

void HAL_TIM_Base_MspInit(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM6) {
        __HAL_RCC_TIM6_CLK_ENABLE();
    }
}

#if !BE_USE_PRECOMPILED_OBJECT
be_native_module_attr_table(attr_table) {
    be_native_module_function("setled", setled),
    be_native_module_function("setdac", setdac),
    be_native_module_function("play_sin", l_play_sin),
    be_native_module_function("play_rect", l_play_rect),
    be_native_module_function("play_tri", l_play_tri),
    be_native_module_function("play_stop", l_play_stop),
    be_native_module_function("reboot", l_reboot)
};

be_define_native_module(board, attr_table);
#else
#include "be_constobj.h"
be_define_const_str_weak(reboot, "reboot", 6);
be_define_const_str_weak(play_stop, "play_stop", 9);
be_define_const_str_weak(play_rect, "play_rect", 9);
be_define_const_str_weak(setdac, "setdac", 6);
be_define_const_str_weak(setled, "setled", 6);
be_define_const_str_weak(play_tri, "play_tri", 8);
be_define_const_str_weak(play_sin, "play_sin", 8);
#include "../../generate/be_fixed_board.h"
#endif
