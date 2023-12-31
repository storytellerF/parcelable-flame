<script setup lang="ts">
interface ParsedBundle {
    id: string
    type: string
    key: string
    size: number
    data: string
    valueSize: number
    children?: [ParsedBundle]
}

const ColorTypes = {
    default: '#8fd3e8',
    /**
     * type
     */
    bundle: '#1bca93',
    /**
     * key
     */
    'androidx.lifecycle.BundlableSavedStateRegistry.key': '#e26290',
    "android:view_state": "#13b9b8",
    "androidx.savedstate.Restarter": "#e1b27b",
    "bundle-key": "#7a30e7",
    "androidx.navigation.NavBackStackEntryState": "#ae101f",
}

import { ref, watchEffect } from 'vue'
import * as echarts from 'echarts'
import stackTrace1 from './assets/bundle.json'

let stackTrace = stackTrace1 as unknown as ParsedBundle

const main = ref(null)

const filterJson = (json: ParsedBundle, id?: string): ParsedBundle => {
    if (id == null) {
        return json
    }

    const recur = (item: ParsedBundle, id?: string): ParsedBundle | undefined => {
        if (item.id === id) {
            return item
        }

        for (const child of item.children || []) {
            const temp = recur(child, id)
            if (temp) {
                item.children = [temp]
                item.valueSize = temp.valueSize // change the parents' values
                return item
            }
        }
    }

    return recur(json, id) || json
}

function isNumber(string: string): boolean {
    for (let index = 0; index < string.length; index++) {
        const element = string[index]
        if (element >= '0' && element <= '9') {
            //
        } else {
            return false
        }
    }
    return true
}

const recursionJson = (jsonObj: ParsedBundle, id?: string): any[] => {
    const data: any[] = []
    const filteredJson = filterJson(structuredClone(jsonObj), id)
    const rootVal = filteredJson.valueSize

    const recur = (item: ParsedBundle, start = 0, level = 0) => {
        var color = ColorTypes[item.key as keyof typeof ColorTypes] || ColorTypes[item.type as keyof typeof ColorTypes]
        if (color == undefined) {
            if (isNumber(item.key)) {
                //
            } else {
                console.log(item.key)
            }
        }
        const temp = {
            name: item.id,
            // [level, start_val, end_val, name, percentage]
            value: [level, start, start + item.valueSize, item.type, (item.valueSize / rootVal) * 100, item],
            itemStyle: {
                color: color || ColorTypes.default
            }
        }
        data.push(temp)

        let prevStart = start
        for (const child of item.children || []) {
            recur(child, prevStart, level + 1)
            prevStart = prevStart + child.valueSize
        }
    }

    recur(filteredJson)
    return data
}

const heightOfJson = (json: ParsedBundle): number => {
    const recur = (item: ParsedBundle, level = 0): number => {
        if ((item.children || []).length === 0) {
            return level
        }

        let maxLevel = level
        for (const child of item.children!) {
            const tempLevel = recur(child, level + 1)
            maxLevel = Math.max(maxLevel, tempLevel)
        }
        return maxLevel
    }

    return recur(json)
}

const renderItem: echarts.CustomSeriesRenderItem = (_params: echarts.CustomSeriesRenderItemParams, api: echarts.CustomSeriesRenderItemAPI) => {
    const level = api.value(0)
    const start = api.coord([api.value(1), level])
    const end = api.coord([api.value(2), level])
    const height = (((api.size && api.size([0, 1])) || [0, 20]) as number[])[1]
    const width = end[0] - start[0]

    return {
        type: 'rect',
        transition: ['shape'],
        shape: {
            x: start[0],
            y: start[1] - height / 2,
            width,
            height: height - 2 /* itemGap */,
            r: 2
        },
        style: {
            fill: api.visual('color')
        },
        emphasis: {
            style: {
                stroke: '#000'
            }
        },
        textConfig: {
            position: 'insideLeft'
        },
        textContent: {
            type: "text",
            style: {
                text: `${api.value(3)}`,
                fontFamily: 'Verdana',
                fill: '#000',
                width: width - 4,
                overflow: 'truncate',
                ellipsis: '..',
                truncateMinChar: 1
            },
            emphasis: {
                style: {
                    stroke: '#000',
                    lineWidth: 0.5
                }
            }
        }
    }
}

watchEffect(() => {
    if (main.value) {
        let myChart = echarts.init(main.value)

        const levelOfOriginalJson = heightOfJson(stackTrace)

        let option: echarts.EChartsOption = {
            backgroundColor: {
                type: 'linear',
                x: 0,
                y: 0,
                x2: 0,
                y2: 1,
                colorStops: [
                    {
                        offset: 0.05,
                        color: '#eee'
                    },
                    {
                        offset: 0.95,
                        color: '#eeeeb0'
                    }
                ]
            },
            tooltip: {
                formatter: (params: any) => {
                    const samples = params.value[2] - params.value[1]
                    const item = params.value[5]
                    return `${params.marker} ${params.value[3]}: (${echarts.format.addCommas(
                        samples
                    )} samples, ${+params.value[4].toFixed(2)}%)
                    <br/>
                    key ${item.key}
                    <br/>
                    data ${item.data || "nil"}
                    <br/>
                    computed size: ${item.valueSize} bundle size: ${item.size}`
                },
                renderMode: "html"
            },
            title: [
                {
                    text: 'Flame Graph',
                    left: 'center',
                    top: 10,
                    textStyle: {
                        fontFamily: 'Verdana',
                        fontWeight: 'normal',
                        fontSize: 20
                    }
                }
            ],
            toolbox: {
                feature: {
                    restore: {}
                },
                right: 20,
                top: 10
            },
            xAxis: {
                show: false
            },
            yAxis: {
                show: false,
                max: levelOfOriginalJson
            },
            series: [
                {
                    type: 'custom',
                    renderItem,
                    encode: {
                        x: [0, 1, 2],
                        y: 0
                    },
                    data: recursionJson(stackTrace)
                }
            ]
        }

        myChart.setOption(option)

        myChart.on('click', (params: any) => {
            const data = recursionJson(stackTrace, params.data.name)
            const rootValue = data[0].value[2]

            myChart.setOption({
                xAxis: { max: rootValue },
                series: [{ data }]
            })
        })
    } else {
        // 此时还未挂载，或此元素已经被卸载（例如通过 v-if 控制）
    }
})
</script>

<template>
    <div id="main" ref="main" style="width: 95vw; height: 95vh; margin: auto"></div>
</template>

<style scoped></style>
