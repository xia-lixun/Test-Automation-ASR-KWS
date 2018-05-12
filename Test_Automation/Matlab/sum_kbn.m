function [sigma, error] = sum_kbn(x, sigma, error)
    
    mInputCompensated = x - error;
    mSumConverge  = sigma + mInputCompensated;
    error = (mSumConverge - sigma) - mInputCompensated;
    sigma = mSumConverge;
   
end


function [y, sigma] = sum_kbn_validation()

    n = 48000*100;
    x = rand(n,1);
    y = sum(x);
    
    sigma = 0;
    error = 0;
    for i = 1:n
        [sigma, error] = sum_kbn(x(i),sigma, error);
    end
end