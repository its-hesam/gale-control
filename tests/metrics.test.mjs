import test from 'node:test';
import assert from 'node:assert/strict';
import {cpuUsage,rate} from '../src/metrics.mjs';
test('first CPU sample is unknown, not fake zero',()=>assert.equal(cpuUsage(null,[1,2,3,4,5,6,7,8]),null));
test('CPU excludes idle and iowait with delta not lifetime totals',()=>assert.equal(cpuUsage([100,0,100,800,0,0,0,0],[110,0,110,870,10,0,0,0]),20));
test('counter reset after reboot cannot produce negative throughput',()=>{assert.equal(rate(1000,10,5),null);assert.equal(cpuUsage([100,0,0,0,0,0,0,0],[10,0,0,0,0,0,0,0]),null)});
test('rates use actual sample interval and reject zero interval',()=>{assert.equal(rate(100,1124,4),256);assert.equal(rate(100,1124,0),null)});
