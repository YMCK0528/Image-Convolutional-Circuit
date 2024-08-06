# Image Convolutional Circuit

2019 IC Design Contest

題目輸入一64*64的灰階圖像，先做Zero-padding，再與Kernel 做 Convolutional，然後做ReLU運算後輸入Layer0

Zero-padding即是在原本的輸入圖像周圍補0，達到相同尺寸；所以利用條件判斷當下的讀address的位置來決定要不要進行運算。
最後再與Kernel進行Convolutional 2^20 * 2^20 * 2^4 = 2^44  By the way 2^4 = 9 pixel，需要注意的是Convolutional完後需要加上bias值，bias值的位元數可能會造成運算錯誤。最好補到同位數之後再運算

之後做ReLU以運算結果最高位元判斷正負，取第17bit+1做4捨5入，輸入Layer0

之後從Layer0把data讀回來做max-pooling，把原本的64*64縮減為32*32，題目以2*2為一組比較，所以讀address時需要以+2的方式進行，利用逐步比大小的方式決定最後要寫入的data，寫入的address則可利用忽略最小位元的方法達到逐步輸入的效果
