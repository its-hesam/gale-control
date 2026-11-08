import {defineConfig} from 'vite';
export default defineConfig({base:'/gale/',build:{target:'es2022'},server:{proxy:{'/ubus':{target:'http://192.168.10.1',changeOrigin:true}}}});
