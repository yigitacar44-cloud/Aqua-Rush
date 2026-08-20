package com.somnyralab.zombiedefense;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.*;
import android.view.MotionEvent;
import android.view.View;
import java.util.*;

public class GameView extends View {
    private enum State { MENU, PLAYING, UPGRADE, GAME_OVER }
    private final Paint p = new Paint(3), stroke = new Paint(3);
    private final Random rng = new Random();
    private final ArrayList<Zombie> zombies = new ArrayList<>();
    private final ArrayList<Bullet> bullets = new ArrayList<>();
    private final ArrayList<Particle> particles = new ArrayList<>();
    private final SharedPreferences prefs;
    private State state = State.MENU;
    private long lastFrame, lastShot, waveStarted, playerInvulnerableUntil;
    private float w, h, scale, px, py, joyX, joyY, aimX, aimY;
    private float moveBaseX, moveBaseY, aimBaseX, aimBaseY, aimDX = 1, aimDY;
    private float screenShake, damageFlash, muzzleFlash;
    private boolean moving, aiming;
    private int movePointer = -1, aimPointer = -1;
    private int hp, maxHp, wave, kills, coins, bestWave, magazine, ammo, damage;
    private float fireDelay, speed, bulletSpeed;
    private String toast = "";
    private long toastUntil;

    public GameView(Context c) {
        super(c);
        setLayerType(View.LAYER_TYPE_HARDWARE, null);
        prefs = c.getSharedPreferences("save", Context.MODE_PRIVATE);
        bestWave = prefs.getInt("bestWave", 0);
        stroke.setStyle(Paint.Style.STROKE); stroke.setStrokeCap(Paint.Cap.ROUND);
    }

    @Override protected void onSizeChanged(int width, int height, int ow, int oh) {
        w = width; h = height; scale = Math.min(w / 1280f, h / 720f);
        if (px == 0) { px = w * .5f; py = h * .56f; }
    }

    private void newGame() {
        hp = maxHp = 100; wave = 1; kills = coins = 0;
        magazine = ammo = 18; damage = 24; fireDelay = 230; speed = 260; bulletSpeed = 820;
        px = w * .5f; py = h * .55f; zombies.clear(); bullets.clear(); particles.clear();
        waveStarted = System.currentTimeMillis(); spawnWave(); state = State.PLAYING;
    }

    private void spawnWave() {
        zombies.clear(); bullets.clear(); ammo = magazine;
        int count = 4 + wave * 2;
        for (int i = 0; i < count; i++) {
            double a = rng.nextDouble() * Math.PI * 2;
            float r = Math.max(w, h) * (.58f + rng.nextFloat() * .25f);
            int type = wave >= 4 && i % 6 == 0 ? 2 : (wave >= 2 && i % 4 == 0 ? 1 : 0);
            zombies.add(new Zombie(px + (float)Math.cos(a)*r, py + (float)Math.sin(a)*r, type, wave));
        }
        waveStarted = System.currentTimeMillis(); showToast("WAVE " + wave, 1400);
    }

    @Override protected void onDraw(Canvas c) {
        super.onDraw(c);
        long now = System.currentTimeMillis();
        float dt = lastFrame == 0 ? 0 : Math.min(.033f, (now-lastFrame)/1000f); lastFrame = now;
        drawGround(c);
        if (state == State.PLAYING) update(dt, now);
        if (screenShake > 0 && state == State.PLAYING) {
            c.save(); c.translate((rng.nextFloat()-.5f)*screenShake*scale,(rng.nextFloat()-.5f)*screenShake*scale);
        }
        if (state != State.MENU) drawWorld(c);
        if (screenShake > 0 && state == State.PLAYING) c.restore();
        if (state == State.MENU) drawMenu(c);
        else if (state == State.PLAYING) drawHud(c, now);
        else if (state == State.UPGRADE) drawUpgrade(c);
        else drawGameOver(c);
        invalidate();
    }

    private void update(float dt, long now) {
        screenShake=Math.max(0,screenShake-dt*55); damageFlash=Math.max(0,damageFlash-dt*2.8f); muzzleFlash=Math.max(0,muzzleFlash-dt*9);
        if (moving) {
            float dx = joyX, dy = joyY, len = (float)Math.hypot(dx,dy);
            if (len > 1) { dx/=len; dy/=len; }
            px += dx*speed*dt; py += dy*speed*dt;
        }
        px = clamp(px, 42*scale, w-42*scale); py = clamp(py, 100*scale, h-42*scale);
        if (!aiming && !zombies.isEmpty()) {
            Zombie target=zombies.get(0); float best=dist2(px,py,target.x,target.y);
            for(Zombie z:zombies){float d=dist2(px,py,z.x,z.y);if(d<best){best=d;target=z;}}
            float tx=target.x-px,ty=target.y-py,len=(float)Math.hypot(tx,ty);
            if(len>1){aimDX=tx/len;aimDY=ty/len;}
        }
        if (!zombies.isEmpty() && now-lastShot >= fireDelay) {
            float dx=aimDX, dy=aimDY, len=(float)Math.hypot(dx,dy);
            if (len>20 && ammo>0) {
                dx/=len; dy/=len; bullets.add(new Bullet(px+dx*28*scale,py+dy*28*scale,dx*bulletSpeed,dy*bulletSpeed));
                ammo--; lastShot=now; muzzleFlash=1; screenShake=Math.max(screenShake,2.5f);
            } else if (ammo==0 && now-lastShot>700) { ammo=magazine; lastShot=now; showToast("RELOADED", 550); }
        }
        for (int i=bullets.size()-1;i>=0;i--) {
            Bullet b=bullets.get(i); b.x+=b.vx*dt; b.y+=b.vy*dt; b.life-=dt;
            boolean remove=b.life<0;
            for (int j=zombies.size()-1;!remove && j>=0;j--) {
                Zombie z=zombies.get(j); float rr=z.radius+7*scale;
                if (dist2(b.x,b.y,z.x,z.y)<rr*rr) {
                    z.hp-=damage; z.flash=.12f; remove=true; burst(b.x,b.y,0xffffd65a,7);
                    if(z.hp<=0){ coins+=z.reward; kills++; burst(z.x,z.y,0xff6c8f35,12); zombies.remove(j); }
                }
            }
            if(remove) bullets.remove(i);
        }
        for (Zombie z:zombies) {
            z.flash=Math.max(0,z.flash-dt);
            float dx=px-z.x,dy=py-z.y,len=(float)Math.hypot(dx,dy);
            if(len>1){ z.x+=dx/len*z.speed*dt;z.y+=dy/len*z.speed*dt; }
            if(len<z.radius+25*scale && now>=playerInvulnerableUntil){
                hp-=Math.max(5,z.damage-4); playerInvulnerableUntil=now+520; damageFlash=1;screenShake=9;burst(px,py,0xffe94b4b,10);
                if(len>1){z.x-=dx/len*30*scale;z.y-=dy/len*30*scale;}
            }
        }
        for(int i=particles.size()-1;i>=0;i--){Particle q=particles.get(i);q.x+=q.vx*dt;q.y+=q.vy*dt;q.life-=dt;if(q.life<=0)particles.remove(i);}
        if(hp<=0){state=State.GAME_OVER;bestWave=Math.max(bestWave,wave);prefs.edit().putInt("bestWave",bestWave).apply();}
        else if(zombies.isEmpty() && now-waveStarted>1000){ coins+=10+wave*2; state=State.UPGRADE; }
    }

    private void drawGround(Canvas c) {
        c.drawColor(Color.rgb(12,18,15));
        p.setColor(0xff17221b); p.setStrokeWidth(1*scale);
        float grid=64*scale;
        for(float x=0;x<w;x+=grid)c.drawLine(x,0,x,h,p);
        for(float y=0;y<h;y+=grid)c.drawLine(0,y,w,y,p);
        p.setColor(0xff1c2a21);
        for(int i=0;i<18;i++){float x=(i*193%1277)/1280f*w,y=(i*317%691)/720f*h;c.drawCircle(x,y,(5+i%4)*scale,p);}
    }

    private void drawWorld(Canvas c) {
        for(Bullet b:bullets){p.setColor(0xffffd65a);p.setStrokeWidth(5*scale);c.drawLine(b.x-b.vx*.012f,b.y-b.vy*.012f,b.x,b.y,p);}
        for(Zombie z:zombies) drawZombie(c,z);
        for(Particle q:particles){p.setColor(q.color);p.setAlpha((int)(255*q.life/.45f));c.drawCircle(q.x,q.y,3.5f*scale,p);p.setAlpha(255);}
        drawPlayer(c);
    }

    private void drawPlayer(Canvas c) {
        float angle=(float)Math.atan2(aimDY,aimDX);
        c.save();c.rotate((float)Math.toDegrees(angle),px,py);
        p.setColor(0xffd7c8a0);c.drawCircle(px,py,21*scale,p);
        p.setColor(0xff2e5b48);c.drawCircle(px-7*scale,py,19*scale,p);
        p.setColor(0xff2c2f2d);round(c,px+2*scale,py-6*scale,px+43*scale,py+6*scale,4*scale,p);
        if(muzzleFlash>0){p.setColor(0xffffe385);c.drawCircle(px+48*scale,py,(5+10*muzzleFlash)*scale,p);}
        c.restore();
        bar(c,px-28*scale,py-38*scale,56*scale,6*scale,hp/(float)maxHp,0xff49c46b);
    }

    private void drawZombie(Canvas c,Zombie z){
        p.setColor(0x55000000);c.drawOval(z.x-z.radius,z.y+z.radius*.45f,z.x+z.radius,z.y+z.radius*.9f,p);
        p.setColor(z.flash>0?0xffffe89c:(z.type==2?0xffa85447:z.type==1?0xff648b39:0xff87aa4c));c.drawCircle(z.x,z.y,z.radius,p);
        p.setColor(0xffd9e36c);c.drawCircle(z.x-z.radius*.32f,z.y-z.radius*.12f,4*scale,p);c.drawCircle(z.x+z.radius*.32f,z.y-z.radius*.12f,4*scale,p);
        stroke.setColor(0xff253020);stroke.setStrokeWidth(3*scale);c.drawLine(z.x-z.radius*.28f,z.y+z.radius*.35f,z.x+z.radius*.3f,z.y+z.radius*.3f,stroke);
        if(z.hp<z.maxHp)bar(c,z.x-z.radius,z.y-z.radius-11*scale,z.radius*2,5*scale,z.hp/z.maxHp,0xffdb5149);
    }

    private void drawHud(Canvas c,long now){
        panel(c,18*scale,16*scale,300*scale,82*scale,14*scale,0xdd101713);
        text(c,"WAVE "+wave,36*scale,36*scale,0xfff0dfb3,true,Paint.Align.LEFT,52*scale);
        text(c,"☠ "+kills+"     $ "+coins,21*scale,36*scale,0xffa7b5a8,false,Paint.Align.LEFT,72*scale);
        panel(c,w-200*scale,18*scale,w-18*scale,78*scale,14*scale,0xdd101713);
        text(c,ammo+" / "+magazine,27*scale,w-36*scale,0xffffd65a,true,Paint.Align.RIGHT,57*scale);
        if(moving) joystick(c,moveBaseX,moveBaseY,joyX,joyY);
        else hintJoystick(c,110*scale,h-112*scale,"MOVE");
        if(aiming)joystick(c,aimBaseX,aimBaseY,aimDX,aimDY);
        else hintJoystick(c,w-110*scale,h-112*scale,"AUTO FIRE");
        stroke.setColor(0x88ffdd62);stroke.setStrokeWidth(2*scale);c.drawLine(px+aimDX*42*scale,py+aimDY*42*scale,px+aimDX*115*scale,py+aimDY*115*scale,stroke);
        if(damageFlash>0){p.setColor(((int)(110*damageFlash)<<24)|0x00c62222);c.drawRect(0,0,w,h,p);}
        if(now<toastUntil) text(c,toast,34*scale,w/2,0xffffdc61,true,Paint.Align.CENTER,80*scale);
    }

    private void drawMenu(Canvas c){
        p.setShader(new LinearGradient(0,0,0,h,0x00000000,0xdd050806,Shader.TileMode.CLAMP));c.drawRect(0,0,w,h,p);p.setShader(null);
        text(c,"LAST STAND",76*scale,w/2,0xfff2e8cc,true,Paint.Align.CENTER,h*.32f);
        text(c,"ZOMBIE DEFENSE",26*scale,w/2,0xff9fc447,true,Paint.Align.CENTER,h*.39f);
        button(c,w/2-170*scale,h*.54f,w/2+170*scale,h*.66f,"START GAME",0xffb4d94e);
        text(c,"Best wave: "+bestWave,20*scale,w/2,0xff89968d,false,Paint.Align.CENTER,h*.74f);
        text(c,"Move with the left stick  •  Weapon fires automatically",18*scale,w/2,0xff647168,false,Paint.Align.CENTER,h*.83f);
    }

    private void drawUpgrade(Canvas c){
        p.setColor(0xdd060a07);c.drawRect(0,0,w,h,p);
        text(c,"WAVE "+wave+" CLEARED",42*scale,w/2,0xffffdc67,true,Paint.Align.CENTER,78*scale);
        text(c,"Choose one upgrade",22*scale,w/2,0xffa9b3ab,false,Paint.Align.CENTER,112*scale);
        float gap=18*scale, cw=270*scale, top=170*scale, left=w/2-(cw*1.5f+gap);
        card(c,left,top,cw,"HEAVY ROUNDS","Damage +8","✦",0);
        card(c,left+cw+gap,top,cw,"RAPID FIRE","Fire rate +15%","⚡",1);
        card(c,left+(cw+gap)*2,top,cw,"MEDKIT","Heal 35 / Max HP +10","+",2);
    }

    private void drawGameOver(Canvas c){
        p.setColor(0xdd090605);c.drawRect(0,0,w,h,p);
        text(c,"THE LINE HAS FALLEN",52*scale,w/2,0xffe15b50,true,Paint.Align.CENTER,h*.3f);
        text(c,"Wave reached: "+wave+"     Kills: "+kills,25*scale,w/2,0xffe7dec8,false,Paint.Align.CENTER,h*.42f);
        text(c,"Best wave: "+bestWave,21*scale,w/2,0xff99a39a,false,Paint.Align.CENTER,h*.49f);
        button(c,w/2-165*scale,h*.58f,w/2+165*scale,h*.7f,"PLAY AGAIN",0xffe1b94c);
    }

    private void card(Canvas c,float x,float y,float cw,String title,String sub,String icon,int id){
        panel(c,x,y,x+cw,y+280*scale,20*scale,0xff172119);
        p.setColor(id==0?0xffd2bd54:id==1?0xff63a9d4:0xff63c77a);c.drawCircle(x+cw/2,y+72*scale,39*scale,p);
        text(c,icon,35*scale,x+cw/2,0xff111713,true,Paint.Align.CENTER,y+84*scale);
        text(c,title,23*scale,x+cw/2,0xfff0e7cf,true,Paint.Align.CENTER,y+145*scale);
        text(c,sub,18*scale,x+cw/2,0xff9eaaa1,false,Paint.Align.CENTER,y+182*scale);
        p.setColor(0xff2d4133);round(c,x+28*scale,y+215*scale,x+cw-28*scale,y+258*scale,10*scale,p);
        text(c,"SELECT",17*scale,x+cw/2,0xffdfe8df,true,Paint.Align.CENTER,y+243*scale);
    }

    @Override public boolean onTouchEvent(MotionEvent e){
        float x=e.getX(),y=e.getY();int action=e.getActionMasked(),idx=e.getActionIndex(),id=e.getPointerId(idx);
        if(action==MotionEvent.ACTION_DOWN && state==State.MENU){newGame();return true;}
        if(action==MotionEvent.ACTION_DOWN && state==State.GAME_OVER){newGame();return true;}
        if(action==MotionEvent.ACTION_DOWN && state==State.UPGRADE){chooseUpgrade(x,y);return true;}
        if(state!=State.PLAYING)return true;
        if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_POINTER_DOWN){
            if(x<w*.48f && movePointer<0){movePointer=id;moving=true;moveBaseX=x;moveBaseY=y;updateMove(x,y);}
            else if(x>w*.52f && aimPointer<0){aimPointer=id;aiming=true;aimBaseX=x;aimBaseY=y;aimX=x;aimY=y;}
        } else if(action==MotionEvent.ACTION_MOVE){
            for(int i=0;i<e.getPointerCount();i++){int pid=e.getPointerId(i);if(pid==movePointer)updateMove(e.getX(i),e.getY(i));if(pid==aimPointer)updateAim(e.getX(i),e.getY(i));}
        } else if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_POINTER_UP||action==MotionEvent.ACTION_CANCEL){
            if(id==movePointer){movePointer=-1;moving=false;joyX=joyY=0;}if(id==aimPointer){aimPointer=-1;aiming=false;}
        } return true;
    }

    private void updateMove(float x,float y){float dx=x-moveBaseX,dy=y-moveBaseY,len=(float)Math.hypot(dx,dy),r=62*scale;if(len>r){dx=dx/len*r;dy=dy/len*r;}joyX=dx/r;joyY=dy/r;}
    private void updateAim(float x,float y){aimX=x;aimY=y;float dx=x-aimBaseX,dy=y-aimBaseY,len=(float)Math.hypot(dx,dy);if(len>10*scale){aimDX=dx/len;aimDY=dy/len;}}
    private void chooseUpgrade(float x,float y){float gap=18*scale,cw=270*scale,left=w/2-(cw*1.5f+gap);int pick=(int)((x-left)/(cw+gap));if(pick<0||pick>2)return;
        if(pick==0)damage+=8;else if(pick==1)fireDelay=Math.max(90,fireDelay*.85f);else{maxHp+=10;hp=Math.min(maxHp,hp+35);}wave++;spawnWave();state=State.PLAYING;}
    private void burst(float x,float y,int color,int n){for(int i=0;i<n;i++){double a=rng.nextDouble()*Math.PI*2;float s=30+rng.nextFloat()*130;particles.add(new Particle(x,y,(float)Math.cos(a)*s,(float)Math.sin(a)*s,color));}}
    private void showToast(String s,long ms){toast=s;toastUntil=System.currentTimeMillis()+ms;}
    private float dist2(float x,float y,float a,float b){float dx=x-a,dy=y-b;return dx*dx+dy*dy;}
    private float clamp(float v,float a,float b){return Math.max(a,Math.min(b,v));}
    private void joystick(Canvas c,float bx,float by,float dx,float dy){p.setColor(0x2227c89a);c.drawCircle(bx,by,66*scale,p);stroke.setColor(0xaa7fa891);stroke.setStrokeWidth(3*scale);c.drawCircle(bx,by,62*scale,stroke);p.setColor(0xddb4c8bb);c.drawCircle(bx+dx*48*scale,by+dy*48*scale,27*scale,p);}
    private void hintJoystick(Canvas c,float bx,float by,String label){stroke.setColor(0x447c9c86);stroke.setStrokeWidth(3*scale);c.drawCircle(bx,by,58*scale,stroke);text(c,label,14*scale,bx,0xff65736a,true,Paint.Align.CENTER,by+5*scale);}
    private void bar(Canvas c,float x,float y,float bw,float bh,float f,int color){p.setColor(0xff283129);round(c,x,y,x+bw,y+bh,bh/2,p);p.setColor(color);round(c,x,y,x+bw*clamp(f,0,1),y+bh,bh/2,p);}
    private void panel(Canvas c,float l,float t,float r,float b,float rad,int color){p.setColor(color);round(c,l,t,r,b,rad,p);}
    private void button(Canvas c,float l,float t,float r,float b,String s,int color){p.setColor(color);round(c,l,t,r,b,15*scale,p);text(c,s,23*scale,(l+r)/2,0xff11150f,true,Paint.Align.CENTER,(t+b)/2+8*scale);}
    private void round(Canvas c,float l,float t,float r,float b,float rad,Paint paint){c.drawRoundRect(l,t,r,b,rad,rad,paint);}
    private void text(Canvas c,String s,float size,float x,int color,boolean bold,Paint.Align align,float y){p.setShader(null);p.setColor(color);p.setTextSize(size);p.setTextAlign(align);p.setTypeface(bold?Typeface.DEFAULT_BOLD:Typeface.DEFAULT);c.drawText(s,x,y,p);}
    private void text(Canvas c,String s,float size,float x,int color,boolean bold,Paint.Align align){text(c,s,size,x,color,bold,align,0);}

    private static class Bullet{float x,y,vx,vy,life=1.2f;Bullet(float x,float y,float vx,float vy){this.x=x;this.y=y;this.vx=vx;this.vy=vy;}}
    private class Zombie{float x,y,hp,maxHp,speed,radius,flash;int damage,reward,type;long lastHit;Zombie(float x,float y,int type,int wave){this.x=x;this.y=y;this.type=type;if(type==2){maxHp=hp=150+wave*18;speed=48+wave*2;radius=34*scale;damage=18;reward=8;}else if(type==1){maxHp=hp=42+wave*7;speed=120+wave*3;radius=21*scale;damage=9;reward=4;}else{maxHp=hp=65+wave*10;speed=72+wave*3;radius=27*scale;damage=12;reward=3;}}}
    private static class Particle{float x,y,vx,vy,life=.45f;int color;Particle(float x,float y,float vx,float vy,int c){this.x=x;this.y=y;this.vx=vx;this.vy=vy;color=c;}}
}
