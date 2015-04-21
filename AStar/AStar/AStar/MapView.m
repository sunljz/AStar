//
//  MapView.m
//  AStar
//
//  Created by 李剑钊 on 15/4/14.
//  Copyright (c) 2015年 sunli. All rights reserved.
//

#import "MapView.h"

const NSInteger mapW = 160;
const NSInteger mapH = 200;
const NSInteger cellW = 20;

const NSInteger type_space = 0;
const NSInteger type_start = 1;
const NSInteger type_end = 2;
const NSInteger type_obstacle = 3;

const NSInteger maxDestoryCount = 1000;
const NSInteger maxArrayCount = 10000;

#define mapColumn (mapW/cellW)
#define mapRow (mapH/cellW)

typedef struct mPoint {
    int x;
    int y;
    int f;
} mPoint;

typedef struct mWay {
    mPoint point;
    struct mWay *pervious;
    struct mWay *next;
} mWay;

@interface MapView () {
    NSInteger mapData[mapColumn][mapRow];
    mWay *start;
    mWay *end;
    
    mWay *openList[maxArrayCount];
    mWay *closeList[maxArrayCount];
    mWay *rightWay[maxArrayCount];
    int rightWayFirstIndex;
    
    // 需要释放的链表
    mWay *destoryArray[maxDestoryCount];
}

@property (nonatomic, assign) int animationIndex;

@end

@implementation MapView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initData];
        [self configObstacleData];
        [self calculateWay];
    }
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (!newSuperview) {
        [self destory];
    }
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor);
    CGContextSetLineWidth(ctx, 1);
    
    CGMutablePathRef path = CGPathCreateMutable();
    for (NSInteger i = 0; i <= mapW; i += cellW) {
        CGPathMoveToPoint(path, NULL, i, 0);
        CGPathAddLineToPoint(path, NULL, i, mapH);
    }
    for (NSInteger i = 0; i <= mapH; i += cellW) {
        CGPathMoveToPoint(path, NULL, 0, i);
        CGPathAddLineToPoint(path, NULL, mapW, i);
    }
    CGContextAddPath(ctx, path);
    CGPathRelease(path);
    CGContextStrokePath(ctx);
    
    CGContextSetFillColorWithColor(ctx, [UIColor redColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(start->point.x*cellW, start->point.y*cellW, cellW, cellW));
    CGContextSetFillColorWithColor(ctx, [UIColor blueColor].CGColor);
    CGContextFillRect(ctx, CGRectMake(end->point.x*cellW, end->point.y*cellW, cellW, cellW));
    
    for (int i = rightWayFirstIndex; i > _animationIndex; i --) {
        mWay *cur = rightWay[i];
        if (cur==NULL) {
            continue;
        }
        mPoint point = cur->point;
        CGContextSetFillColorWithColor(ctx, [[UIColor yellowColor] colorWithAlphaComponent:0.3].CGColor);
        CGContextFillRect(ctx, CGRectMake(point.x*cellW, point.y*cellW, cellW, cellW));
    }
    /*
    CGContextSetFillColorWithColor(ctx, [[UIColor redColor] colorWithAlphaComponent:0.3].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, cellW, cellW));
    */
    [self drawObstacle:ctx];
}

- (void)drawObstacle:(CGContextRef)ctx {
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    for (NSInteger i = 0; i < mapColumn; i ++) {
        for (NSInteger j = 0; j < mapRow; j ++) {
			
            if (mapData[i][j] == type_obstacle) {
                CGRect frame = CGRectMake(i*cellW, j*cellW, cellW, cellW);
                CGContextFillRect(ctx, frame);
            }
        }
    }
    
}

#pragma mark - data

- (void)initData {
    for (NSInteger i = 0; i < mapColumn; i ++) {
        for (NSInteger j = 0; j < mapRow; j ++) {
            mapData[i][j] = 0;
        }
    }
    
    for (int i = 0; i < maxDestoryCount; i ++) {
        destoryArray[i] = NULL;
    }
    for (int i = 0; i < maxArrayCount; i ++) {
        openList[i] = NULL;
        closeList[i] = NULL;
        rightWay[i] = NULL;
    }
    rightWayFirstIndex = 0;
    
    start = (mWay *)malloc(sizeof(mWay));
    end = (mWay *)malloc(sizeof(mWay));
    [self addPointToDestoryArray:start];
    [self addPointToDestoryArray:end];
    
    start->pervious = NULL;
    start->next = NULL;
    start->point.x = 0;
    start->point.y = 2;
    start->point.f = 0;
    end->pervious = NULL;
    end->next = NULL;
    end->point.x = 6;
    end->point.y = 2;
    end->point.f = 0;
    
    start->point.f = abs(end->point.x - start->point.x) + abs(end->point.y - start->point.y);
    end->point.f = start->point.f;
}

- (void)configObstacleData {
    mapData[0][1] = type_obstacle;
    mapData[1][1] = type_obstacle;
    mapData[2][1] = type_obstacle;
    mapData[3][1] = type_obstacle;
    mapData[4][1] = type_obstacle;
    mapData[4][2] = type_obstacle;
    mapData[4][3] = type_obstacle;
    mapData[4][4] = type_obstacle;
    mapData[3][4] = type_obstacle;
    mapData[2][4] = type_obstacle;
    mapData[1][4] = type_obstacle;
//    mapData[0][4] = type_obstacle;
}

#pragma mark - calculate

- (void)calculateWay {
    // 把起始格添加到"开启列表"
    [self addWayToOpenList:start];
    
    do {
        // 寻找f值最低的格子, 设置为当前格
        mWay *curWay = [self getShortWayInOpenList];
        [self removeWayInOpenList:curWay];
        [self addWayToCloseList:curWay];
        
        // 对当前格相邻的4格中的每一格遍历(不允许斜线运动)
        for (int i = -1; i < 2; i ++) {
            for (int j = -1; j < 2; j ++) {
                if (i*j !=0) {
                    continue;
                } else if (i == 0 && j == 0) {
                    continue;
                }
                
                int x = curWay->point.x + i;
                int y = curWay->point.y + j;
                if (x < 0 || y < 0 || x > mapColumn || y > mapRow) {
                    continue;
                }
                if (mapData[x][y] == type_obstacle) {
                    // 障碍物 什么也不做
                    continue;
                }
                if ([self isInCloseLink:x y:y]) {
                    // 已经在关闭列表中 什么也不做
                    continue;
                }
                
                int gNext = abs(start->point.x - x) + abs(start->point.y - y);
                int hNext = abs(end->point.x - x) + abs(end->point.y - y);
                int fNext = gNext + hNext;
                if ([self isInOpenList:x y:y]) {
                    // 已经在开启列表中 用F值为参考检查新的路径是否更好, 更低的F值意味着更好的路径
                    if (fNext < curWay->point.f) {
                        // 把这一格的父节点改成当前格, 并且重新计算这一格的 GF 值
                        mWay *nextWay = [self getWayInOpenLink:x y:y];
                        nextWay->point.f = fNext;
                        nextWay->pervious = curWay;
                    }
                } else if ([self isEnd:x y:y]) {
                    // 找到了
                    end->pervious = curWay;
                    [self addWayToOpenList:end];
                    break;
                } else {
                    // 不在开启列表中 把它添加进 "开启列表", 把当前格作为这一格的父节点, 计算这一格的 FGH
                    mWay *nextW = (mWay *)malloc(sizeof(mWay));
                    nextW->point.x = x;
                    nextW->point.y = y;
                    nextW->point.f = fNext;
                    nextW->next = NULL;
                    nextW->pervious = curWay;
                    [self addWayToOpenList:nextW];
                    [self addPointToDestoryArray:nextW];
                }
            }
        }
        
        if (curWay->next == NULL) {
            // 没有下一步
            [self removeWayInOpenList:curWay];
            [self addWayToCloseList:curWay];
        }
        
        if (openList[0] == NULL) {
            break;
        }
    } while (![self isInOpenList:end->point.x y:end->point.y]);
    
    if ([self isInOpenList:end->point.x y:end->point.y]) {
        [self finishCalculate];
    } else {
        [self failedCalculate];
    }
}

- (void)addWayToOpenList:(mWay *)way {
    if (way == NULL) {
        return;
    }
    
    for (int i = 0; i < maxArrayCount; i ++) {
        if (openList[i] != NULL) {
            continue;
        } else {
            openList[i] = way;
            break;
        }
    }
}

- (void)removeWayInOpenList:(mWay *)way {
    if (way == NULL) {
        return;
    }
    BOOL hadFind = NO;
    for (int i = 0; i < maxArrayCount; i ++) {
        mWay *sub = openList[i];
        if (sub == NULL) {
            // 尽头
            break;
        }
        if (!hadFind) {
            if (sub->point.x == way->point.x && sub->point.y == way->point.y) {
                // 找到
                hadFind = YES;
            }
        }
        if (hadFind && i < maxArrayCount-1) {
            mWay *next = openList[i+1];
            openList[i] = next;
        } else if (hadFind && i == maxArrayCount-1) {
            openList[i] = NULL;
        }
    }
}

- (mWay *)getShortWayInOpenList {
    mWay *shortWay = openList[0];
    if (maxArrayCount <= 1) {
        return NULL;
    }
    
    for (int i = 1; i < maxArrayCount; i ++) {
        mWay *next = openList[i];
        if (next == NULL) {
            break;
        }
        if (next->point.f < shortWay->point.f) {
            shortWay = next;
        }
    }
    return shortWay;
}

- (BOOL)isInOpenList:(NSInteger)x y:(NSInteger)y {
    BOOL hadPoint = NO;
    for (int i = 0; i < maxArrayCount; i ++) {
        mWay *sub = openList[i];
        if (sub == NULL) {
            break;
        }
        if (sub->point.x == x && sub->point.y == y) {
            hadPoint = YES;
            break;
        }
    }
    return hadPoint;
}

- (mWay *)getWayInOpenLink:(NSInteger)x y:(NSInteger)y {
    mWay *target = NULL;
    for (int i = 0; i < maxArrayCount; i ++) {
        mWay *sub = openList[i];
        if (sub == NULL) {
            break;
        }
        if (sub->point.x == x && sub->point.y == y) {
            target = sub;
            break;
        }
    }
    return target;
}

- (void)addWayToCloseList:(mWay *)way {
    if (way == NULL) {
        return;
    }
    
    for (int i = 0; i < maxArrayCount; i ++) {
        if (closeList[i] != NULL) {
            continue;
        } else {
            closeList[i] = way;
            break;
        }
    }
}

- (BOOL)isInCloseLink:(NSInteger)x y:(NSInteger)y {
    BOOL hadPoint = NO;
    for (int i = 0; i < maxArrayCount; i ++) {
        mWay *sub = closeList[i];
        if (sub == NULL) {
            break;
        }
        if (sub->point.x == x && sub->point.y == y) {
            hadPoint = YES;
            break;
        }
    }
    return hadPoint;
}

- (BOOL)isEnd:(NSInteger)x y:(NSInteger)y {
    mPoint point = end->point;
    if (point.x == x && point.y == y) {
        return YES;
    }
    return NO;
}

- (void)finishCalculate {
    NSLog(@"finish");
    mWay *cur = end;
    int index = 0;
    while (cur != NULL) {
        rightWay[index] = cur;
        index ++;
        mWay *per = cur->pervious;
        cur = per;
        if (cur == NULL) {
            index --;
        }
    }
    rightWayFirstIndex = index;
    _animationIndex = index;
    [self goAnimation];
}

- (void)goAnimation {
    _animationIndex --;
    [self setNeedsDisplay];
    [self performSelector:@selector(goAnimation) withObject:nil afterDelay:0.5];
}

- (void)failedCalculate {
    NSLog(@"failed");
}

#pragma mark - destory

- (void)addPointToDestoryArray:(void *)point {
    for (int i = 0; i < maxDestoryCount; i ++) {
        if (destoryArray[i] == NULL) {
            destoryArray[i] = point;
            break;
        }
    }
}

- (void)destory {
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
    
    free(start);
    start = NULL;
    free(end);
    end = NULL;
    
    for (int i = 0; i < maxDestoryCount; i ++) {
        if (destoryArray[i] != NULL) {
            void *point = destoryArray[i];
            free(point);
            point = NULL;
            destoryArray[i] = NULL;
        } else {
            break;
        }
    }
}

- (void)dealloc {
    [self destory];
}

@end
